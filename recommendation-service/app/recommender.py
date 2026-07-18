import logging
import math
import os
from collections import Counter, defaultdict
from datetime import datetime, timezone
from typing import Any

import numpy as np
from firebase_admin import firestore

logger = logging.getLogger(__name__)

# Firestore allows max 500 ops per batch; keep a margin.
_BATCH_LIMIT = 400


class RecommendationEngine:
    def __init__(self, db: firestore.Client):
        self.db = db
        self.top_n = int(os.getenv("TOP_N", "10"))
        self.min_similarity = float(os.getenv("MIN_SIMILARITY", "0.0"))

    def train(self) -> dict[str, Any]:
        purchases = self._load_purchase_history()
        products = self._load_products()
        purchaser_ids = sorted({p["userId"] for p in purchases if p.get("userId")})
        customer_ids = self._load_customer_ids()
        # Train for everyone who bought something, plus other customers (cold start).
        users = sorted(set(purchaser_ids) | set(customer_ids))

        if not products:
            self._save_training_log(len(purchases), len(users), 0, "no_available_products")
            return {
                "status": "ok",
                "message": "No available products found.",
                "purchases": len(purchases),
                "users": len(users),
                "products": 0,
            }

        matrix, user_index, product_index = self._build_user_product_matrix(
            purchases,
            products,
        )
        similarity = self._cosine_similarity(matrix)
        popular = self._popular_products(purchases, products)

        batch = self.db.batch()
        ops = 0
        generated = 0

        for user_id in users:
            recommendations = self._recommend_for_user(
                user_id=user_id,
                purchases=purchases,
                products=products,
                matrix=matrix,
                user_index=user_index,
                product_index=product_index,
                similarity=similarity,
                popular=popular,
            )
            # Never write empty docs — catalog fallback guarantees items when stock exists.
            if not recommendations:
                recommendations = self._catalog_fallback(
                    products,
                    exclude=set(),
                    limit=self.top_n,
                )
            source = (
                "collaborative_filtering"
                if user_id in user_index
                else "cold_start"
            )
            self._set_recommendation_doc(batch, user_id, recommendations, source=source)
            generated += 1
            ops += 1
            if ops >= _BATCH_LIMIT:
                batch.commit()
                batch = self.db.batch()
                ops = 0

        if ops > 0:
            batch.commit()

        metrics = self.evaluate(purchases, products)
        self._save_training_log(len(purchases), len(users), generated, "trained", metrics)
        logger.info(
            "Training complete: purchases=%s users=%s recommendation_docs=%s",
            len(purchases),
            len(users),
            generated,
        )
        return {
            "status": "ok",
            "purchases": len(purchases),
            "users": len(users),
            "products": len(products),
            "recommendationDocs": generated,
            "metrics": metrics,
        }

    def get_recommendations(self, user_id: str) -> dict[str, Any]:
        doc = self.db.collection("recommendations").document(user_id).get()
        if doc.exists:
            data = doc.to_dict() or {}
            items = data.get("items") or []
            if items:
                return {
                    "userId": user_id,
                    "recommendations": items,
                    "source": data.get("source", "collaborative_filtering"),
                }

        purchases = self._load_purchase_history()
        products = self._load_products()
        return {
            "userId": user_id,
            "recommendations": self._cold_start_recommendations(
                user_id,
                purchases,
                products,
            ),
            "source": "cold_start",
        }

    def _load_purchase_history(self) -> list[dict[str, Any]]:
        docs = self.db.collection("purchase_history").stream()
        purchases: list[dict[str, Any]] = []
        for doc in docs:
            data = doc.to_dict() or {}
            if data.get("userId") and data.get("productId"):
                purchases.append({"id": doc.id, **data})
        return purchases

    def _load_products(self) -> dict[str, dict[str, Any]]:
        docs = self.db.collection("products").stream()
        products: dict[str, dict[str, Any]] = {}
        for doc in docs:
            data = doc.to_dict() or {}
            if data.get("isAvailable") is False:
                continue
            if float(data.get("stock") or 0) <= 0:
                continue
            products[doc.id] = {"id": doc.id, **data}
        return products

    def _load_customer_ids(self) -> list[str]:
        """Customers who should receive cold-start recommendations even without purchases."""
        ids: list[str] = []
        try:
            docs = (
                self.db.collection("users")
                .where("role", "==", "customer")
                .stream()
            )
            for doc in docs:
                ids.append(doc.id)
        except Exception:
            # Missing index / empty collection — fall back to all users and filter client-side.
            logger.warning("Could not query users by role; loading all users for cold start")
            for doc in self.db.collection("users").stream():
                data = doc.to_dict() or {}
                role = (data.get("role") or "customer").lower()
                if role == "customer":
                    ids.append(doc.id)
        return ids

    def _build_user_product_matrix(
        self,
        purchases: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
    ) -> tuple[np.ndarray, dict[str, int], dict[str, int]]:
        users = sorted({p["userId"] for p in purchases})
        product_ids = sorted(products.keys())
        user_index = {user_id: i for i, user_id in enumerate(users)}
        product_index = {product_id: i for i, product_id in enumerate(product_ids)}
        matrix = np.zeros((len(users), len(product_ids)), dtype=float)

        for purchase in purchases:
            user_id = purchase["userId"]
            product_id = purchase["productId"]
            if product_id not in product_index:
                continue
            quantity = float(purchase.get("quantity") or 1)
            matrix[user_index[user_id], product_index[product_id]] += max(quantity, 1.0)

        return matrix, user_index, product_index

    def _cosine_similarity(self, matrix: np.ndarray) -> np.ndarray:
        if matrix.size == 0:
            return np.zeros((0, 0), dtype=float)

        item_vectors = matrix.T
        norms = np.linalg.norm(item_vectors, axis=1)
        denominator = np.outer(norms, norms)
        numerator = item_vectors @ item_vectors.T
        similarity = np.divide(
            numerator,
            denominator,
            out=np.zeros_like(numerator, dtype=float),
            where=denominator != 0,
        )
        np.fill_diagonal(similarity, 0.0)
        return similarity

    def _recommend_for_user(
        self,
        user_id: str,
        purchases: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
        matrix: np.ndarray,
        user_index: dict[str, int],
        product_index: dict[str, int],
        similarity: np.ndarray,
        popular: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        if user_id not in user_index:
            return self._cold_start_recommendations(user_id, purchases, products)

        user_vector = matrix[user_index[user_id]]
        purchased_indexes = np.where(user_vector > 0)[0]
        if len(purchased_indexes) == 0:
            return self._cold_start_recommendations(user_id, purchases, products)

        scores = similarity[:, purchased_indexes] @ user_vector[purchased_indexes]
        reverse_product_index = {index: product_id for product_id, index in product_index.items()}
        purchased_product_ids = {
            reverse_product_index[index] for index in purchased_indexes
        }

        scored: list[dict[str, Any]] = []
        for index, score in enumerate(scores):
            product_id = reverse_product_index[index]
            product = products.get(product_id, {})
            repeat_buy = bool(product.get("repeatBuy"))
            if product_id in purchased_product_ids and not repeat_buy:
                continue
            if score <= self.min_similarity:
                continue
            scored.append(
                {
                    "productId": product_id,
                    "score": round(float(score), 6),
                    "reason": "similar_to_previous_purchases",
                }
            )

        scored.sort(key=lambda item: item["score"], reverse=True)
        seen = {item["productId"] for item in scored}

        # Fill with popular (purchase-based + catalog-padded).
        if len(scored) < self.top_n:
            for item in popular:
                if item["productId"] in seen:
                    continue
                product = products.get(item["productId"], {})
                if item["productId"] in purchased_product_ids and not product.get("repeatBuy"):
                    continue
                scored.append(item)
                seen.add(item["productId"])
                if len(scored) >= self.top_n:
                    break

        # Final safety net: any remaining available products from catalog.
        if len(scored) < self.top_n:
            exclude_purchased = {
                pid
                for pid in purchased_product_ids
                if not products.get(pid, {}).get("repeatBuy")
            }
            for item in self._catalog_fallback(
                products,
                exclude=seen | exclude_purchased,
                limit=self.top_n - len(scored),
            ):
                if item["productId"] in seen:
                    continue
                scored.append(item)
                seen.add(item["productId"])

        return scored[: self.top_n]

    def _popular_products(
        self,
        purchases: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
    ) -> list[dict[str, Any]]:
        counts: Counter[str] = Counter()
        for purchase in purchases:
            product_id = purchase.get("productId")
            if product_id in products:
                counts[product_id] += int(purchase.get("quantity") or 1)

        items: list[dict[str, Any]] = []
        seen: set[str] = set()

        if counts:
            for product_id, quantity in counts.most_common():
                items.append(
                    {
                        "productId": product_id,
                        "score": round(math.log(quantity + 1), 6),
                        "reason": "popular_product",
                    }
                )
                seen.add(product_id)

        # Always pad with other available catalog products so sparse markets
        # still get recommendations after excluding already-purchased items.
        for item in self._catalog_fallback(products, exclude=seen, limit=self.top_n * 3):
            if item["productId"] in seen:
                continue
            items.append(item)
            seen.add(item["productId"])

        return items[: max(self.top_n * 3, self.top_n)]

    def _catalog_fallback(
        self,
        products: dict[str, dict[str, Any]],
        exclude: set[str],
        limit: int,
    ) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        # Prefer higher stock / more recently stocked-looking items by stock desc.
        ranked = sorted(
            products.values(),
            key=lambda p: float(p.get("stock") or 0),
            reverse=True,
        )
        for product in ranked:
            product_id = product["id"]
            if product_id in exclude:
                continue
            items.append(
                {
                    "productId": product_id,
                    "score": 0.5,
                    "reason": "available_product",
                }
            )
            if len(items) >= limit:
                break
        return items

    def _cold_start_recommendations(
        self,
        user_id: str,
        purchases: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
    ) -> list[dict[str, Any]]:
        preference = self._category_preference(user_id)
        popular = self._popular_products(purchases, products)
        if not preference:
            return popular[: self.top_n]

        preferred = [
            item
            for item in popular
            if products.get(item["productId"], {}).get("category") == preference
        ]
        remaining = [item for item in popular if item not in preferred]
        filled = (preferred + remaining)[: self.top_n]
        if len(filled) < self.top_n:
            seen = {item["productId"] for item in filled}
            filled.extend(
                self._catalog_fallback(
                    products,
                    exclude=seen,
                    limit=self.top_n - len(filled),
                )
            )
        return filled[: self.top_n]

    def _category_preference(self, user_id: str) -> str | None:
        doc = self.db.collection("users").document(user_id).get()
        if not doc.exists:
            return None
        data = doc.to_dict() or {}
        return data.get("preferredCategory") or data.get("categoryPreference")

    def _set_recommendation_doc(
        self,
        batch: firestore.WriteBatch,
        user_id: str,
        recommendations: list[dict[str, Any]],
        source: str = "collaborative_filtering",
    ) -> None:
        ref = self.db.collection("recommendations").document(user_id)
        batch.set(
            ref,
            {
                "userId": user_id,
                "items": recommendations,
                "source": source,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )

    def evaluate(
        self,
        purchases: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
        k: int = 5,
    ) -> dict[str, Any]:
        by_user: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for purchase in purchases:
            by_user[purchase["userId"]].append(purchase)

        test_items: dict[str, str] = {}
        train_purchases: list[dict[str, Any]] = []
        for user_id, items in by_user.items():
            items = sorted(items, key=lambda item: str(item.get("purchaseDate") or ""))
            if len(items) < 2:
                train_purchases.extend(items)
                continue
            test_items[user_id] = items[-1]["productId"]
            train_purchases.extend(items[:-1])

        if not test_items:
            return {"precisionAtK": 0.0, "recallAtK": 0.0, "topNAccuracy": 0.0, "evaluatedUsers": 0}

        matrix, user_index, product_index = self._build_user_product_matrix(train_purchases, products)
        similarity = self._cosine_similarity(matrix)
        popular = self._popular_products(train_purchases, products)

        hits = 0
        for user_id, expected_product_id in test_items.items():
            recommended = self._recommend_for_user(
                user_id,
                train_purchases,
                products,
                matrix,
                user_index,
                product_index,
                similarity,
                popular,
            )[:k]
            if expected_product_id in {item["productId"] for item in recommended}:
                hits += 1

        evaluated_users = len(test_items)
        precision = hits / (evaluated_users * k)
        recall = hits / evaluated_users
        return {
            "precisionAtK": round(precision, 6),
            "recallAtK": round(recall, 6),
            "topNAccuracy": round(recall, 6),
            "evaluatedUsers": evaluated_users,
        }

    def _save_training_log(
        self,
        purchases: int,
        users: int,
        recommendation_docs: int,
        status: str,
        metrics: dict[str, Any] | None = None,
    ) -> None:
        self.db.collection("recommendation_training_logs").add(
            {
                "trainedAt": datetime.now(timezone.utc),
                "purchaseCount": purchases,
                "userCount": users,
                "recommendationDocs": recommendation_docs,
                "status": status,
                "metrics": metrics or {},
            }
        )
