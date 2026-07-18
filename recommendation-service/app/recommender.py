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

# Implicit-feedback weights (professional hybrid-style signal mix).
_EVENT_WEIGHTS = {
    "view": 1.0,
    "click": 2.0,
    "add_to_cart": 3.5,
    "purchase": 5.0,
}


class RecommendationEngine:
    """
    Hybrid recommender:
      1) Item-item collaborative filtering on purchases + interactions
      2) Content affinity (same category as user preferences)
      3) Popularity prior
    Works with sparse data by always filling from content + catalog.
    """

    def __init__(self, db: firestore.Client):
        self.db = db
        self.top_n = int(os.getenv("TOP_N", "10"))
        self.min_similarity = float(os.getenv("MIN_SIMILARITY", "0.0"))
        self.w_cf = float(os.getenv("W_CF", "0.45"))
        self.w_content = float(os.getenv("W_CONTENT", "0.35"))
        self.w_pop = float(os.getenv("W_POP", "0.20"))

    def train(self) -> dict[str, Any]:
        purchases = self._load_purchase_history()
        interactions = self._load_interactions()
        products = self._load_products()
        purchaser_ids = {p["userId"] for p in purchases if p.get("userId")}
        interactor_ids = {e["userId"] for e in interactions if e.get("userId")}
        customer_ids = set(self._load_customer_ids())
        users = sorted(purchaser_ids | interactor_ids | customer_ids)

        if not products:
            self._save_training_log(
                len(purchases), len(users), 0, "no_available_products",
                event_count=len(interactions),
            )
            return {
                "status": "ok",
                "message": "No available products found.",
                "purchases": len(purchases),
                "events": len(interactions),
                "users": len(users),
                "products": 0,
            }

        # Build combined implicit-feedback matrix (purchases + events).
        matrix, user_index, product_index = self._build_interaction_matrix(
            purchases,
            interactions,
            products,
        )
        similarity = self._cosine_similarity(matrix)
        popular_scores = self._popularity_scores(purchases, interactions, products)
        category_index = self._build_category_index(products)

        batch = self.db.batch()
        ops = 0
        generated = 0

        for user_id in users:
            recommendations = self._hybrid_recommend(
                user_id=user_id,
                purchases=purchases,
                interactions=interactions,
                products=products,
                matrix=matrix,
                user_index=user_index,
                product_index=product_index,
                similarity=similarity,
                popular_scores=popular_scores,
                category_index=category_index,
            )
            if not recommendations:
                recommendations = self._catalog_fallback(
                    products,
                    exclude=set(),
                    limit=self.top_n,
                )
            source = self._source_label(user_id, user_index, purchases, interactions)
            self._set_recommendation_doc(batch, user_id, recommendations, source=source)
            generated += 1
            ops += 1
            if ops >= _BATCH_LIMIT:
                batch.commit()
                batch = self.db.batch()
                ops = 0

        if ops > 0:
            batch.commit()

        metrics = self.evaluate(purchases, interactions, products)
        self._save_training_log(
            len(purchases),
            len(users),
            generated,
            "trained",
            metrics,
            event_count=len(interactions),
        )
        logger.info(
            "Hybrid training complete: purchases=%s events=%s users=%s docs=%s",
            len(purchases),
            len(interactions),
            len(users),
            generated,
        )
        return {
            "status": "ok",
            "purchases": len(purchases),
            "events": len(interactions),
            "users": len(users),
            "products": len(products),
            "recommendationDocs": generated,
            "metrics": metrics,
            "weights": {
                "cf": self.w_cf,
                "content": self.w_content,
                "popularity": self.w_pop,
            },
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
                    "source": data.get("source", "hybrid"),
                }

        purchases = self._load_purchase_history()
        interactions = self._load_interactions()
        products = self._load_products()
        matrix, user_index, product_index = self._build_interaction_matrix(
            purchases, interactions, products,
        )
        similarity = self._cosine_similarity(matrix)
        popular_scores = self._popularity_scores(purchases, interactions, products)
        category_index = self._build_category_index(products)
        return {
            "userId": user_id,
            "recommendations": self._hybrid_recommend(
                user_id,
                purchases,
                interactions,
                products,
                matrix,
                user_index,
                product_index,
                similarity,
                popular_scores,
                category_index,
            ),
            "source": "hybrid_live",
        }

    # ── data loading ──────────────────────────────────────────────────────────

    def _load_purchase_history(self) -> list[dict[str, Any]]:
        docs = self.db.collection("purchase_history").stream()
        purchases: list[dict[str, Any]] = []
        for doc in docs:
            data = doc.to_dict() or {}
            if data.get("userId") and data.get("productId"):
                purchases.append({"id": doc.id, **data})
        return purchases

    def _load_interactions(self) -> list[dict[str, Any]]:
        events: list[dict[str, Any]] = []
        try:
            docs = self.db.collection("user_interactions").stream()
            for doc in docs:
                data = doc.to_dict() or {}
                if data.get("userId") and data.get("productId") and data.get("type"):
                    events.append({"id": doc.id, **data})
        except Exception:
            logger.exception("Failed to load user_interactions")
        return events

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
        ids: list[str] = []
        try:
            docs = self.db.collection("users").where("role", "==", "customer").stream()
            for doc in docs:
                ids.append(doc.id)
        except Exception:
            logger.warning("Could not query users by role; scanning users collection")
            for doc in self.db.collection("users").stream():
                data = doc.to_dict() or {}
                role = (data.get("role") or "customer").lower()
                if role == "customer":
                    ids.append(doc.id)
        return ids

    # ── matrix / similarity ───────────────────────────────────────────────────

    def _build_interaction_matrix(
        self,
        purchases: list[dict[str, Any]],
        interactions: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
    ) -> tuple[np.ndarray, dict[str, int], dict[str, int]]:
        users = sorted(
            {p["userId"] for p in purchases if p.get("userId")}
            | {e["userId"] for e in interactions if e.get("userId")}
        )
        product_ids = sorted(products.keys())
        user_index = {user_id: i for i, user_id in enumerate(users)}
        product_index = {product_id: i for i, product_id in enumerate(product_ids)}
        matrix = np.zeros((len(users), len(product_ids)), dtype=float)
        if not users or not product_ids:
            return matrix, user_index, product_index

        for purchase in purchases:
            user_id = purchase.get("userId")
            product_id = purchase.get("productId")
            if user_id not in user_index or product_id not in product_index:
                continue
            qty = max(float(purchase.get("quantity") or 1), 1.0)
            matrix[user_index[user_id], product_index[product_id]] += (
                _EVENT_WEIGHTS["purchase"] * qty
            )

        for event in interactions:
            user_id = event.get("userId")
            product_id = event.get("productId")
            if user_id not in user_index or product_id not in product_index:
                continue
            etype = str(event.get("type") or "view").lower()
            weight = _EVENT_WEIGHTS.get(etype, _EVENT_WEIGHTS["view"])
            matrix[user_index[user_id], product_index[product_id]] += weight

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

    def _build_category_index(
        self,
        products: dict[str, dict[str, Any]],
    ) -> dict[str, list[str]]:
        by_cat: dict[str, list[str]] = defaultdict(list)
        for product_id, product in products.items():
            cat = str(product.get("category") or "").strip().lower()
            if cat:
                by_cat[cat].append(product_id)
        return by_cat

    def _popularity_scores(
        self,
        purchases: list[dict[str, Any]],
        interactions: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
    ) -> dict[str, float]:
        counts: Counter[str] = Counter()
        for purchase in purchases:
            pid = purchase.get("productId")
            if pid in products:
                counts[pid] += int(purchase.get("quantity") or 1) * 3
        for event in interactions:
            pid = event.get("productId")
            if pid in products:
                etype = str(event.get("type") or "view").lower()
                counts[pid] += int(_EVENT_WEIGHTS.get(etype, 1.0))

        if not counts:
            # Uniform prior over available catalog.
            return {pid: 0.5 for pid in products}

        max_log = max(math.log(c + 1) for c in counts.values()) or 1.0
        scores = {
            pid: math.log(count + 1) / max_log
            for pid, count in counts.items()
        }
        # Unseen products get a small baseline so they can still surface.
        for pid in products:
            scores.setdefault(pid, 0.15)
        return scores

    # ── hybrid scoring ────────────────────────────────────────────────────────

    def _user_signals(
        self,
        user_id: str,
        purchases: list[dict[str, Any]],
        interactions: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
    ) -> tuple[set[str], Counter[str], str | None]:
        interacted: set[str] = set()
        category_weights: Counter[str] = Counter()

        for purchase in purchases:
            if purchase.get("userId") != user_id:
                continue
            pid = purchase.get("productId")
            if not pid:
                continue
            interacted.add(pid)
            cat = (
                purchase.get("category")
                or products.get(pid, {}).get("category")
            )
            if cat:
                category_weights[str(cat).lower()] += 5

        for event in interactions:
            if event.get("userId") != user_id:
                continue
            pid = event.get("productId")
            if not pid:
                continue
            interacted.add(pid)
            etype = str(event.get("type") or "view").lower()
            w = _EVENT_WEIGHTS.get(etype, 1.0)
            cat = event.get("category") or products.get(pid, {}).get("category")
            if cat:
                category_weights[str(cat).lower()] += w

        profile_cat = self._category_preference(user_id)
        if profile_cat:
            category_weights[str(profile_cat).lower()] += 2

        top_category = category_weights.most_common(1)[0][0] if category_weights else None
        return interacted, category_weights, top_category

    def _hybrid_recommend(
        self,
        user_id: str,
        purchases: list[dict[str, Any]],
        interactions: list[dict[str, Any]],
        products: dict[str, dict[str, Any]],
        matrix: np.ndarray,
        user_index: dict[str, int],
        product_index: dict[str, int],
        similarity: np.ndarray,
        popular_scores: dict[str, float],
        category_index: dict[str, list[str]],
    ) -> list[dict[str, Any]]:
        interacted, category_weights, top_category = self._user_signals(
            user_id, purchases, interactions, products,
        )
        reverse_product_index = {
            index: product_id for product_id, index in product_index.items()
        }

        # CF scores from item similarity × user vector.
        cf_raw: dict[str, float] = {pid: 0.0 for pid in products}
        if user_id in user_index and matrix.size and product_index:
            user_vector = matrix[user_index[user_id]]
            active = np.where(user_vector > 0)[0]
            if len(active) > 0:
                scores = similarity[:, active] @ user_vector[active]
                for index, score in enumerate(scores):
                    pid = reverse_product_index.get(index)
                    if pid:
                        cf_raw[pid] = float(score)

        max_cf = max(cf_raw.values()) if cf_raw else 0.0
        if max_cf <= 0:
            max_cf = 1.0

        # Content: normalized affinity to categories the user likes.
        max_cat_w = max(category_weights.values()) if category_weights else 1.0
        content_raw: dict[str, float] = {}
        for pid, product in products.items():
            cat = str(product.get("category") or "").strip().lower()
            if cat and cat in category_weights:
                content_raw[pid] = category_weights[cat] / max_cat_w
            elif top_category and cat == top_category:
                content_raw[pid] = 1.0
            else:
                content_raw[pid] = 0.0

        # If user has no signal at all, boost globally popular + slight content diversity.
        if not interacted and not category_weights:
            for pid in products:
                content_raw[pid] = 0.0

        scored: list[dict[str, Any]] = []
        for pid, product in products.items():
            repeat_buy = bool(product.get("repeatBuy"))
            if pid in interacted and not repeat_buy:
                continue

            cf_n = cf_raw.get(pid, 0.0) / max_cf
            content_n = content_raw.get(pid, 0.0)
            pop_n = float(popular_scores.get(pid, 0.15))

            hybrid = (
                self.w_cf * max(cf_n, 0.0)
                + self.w_content * content_n
                + self.w_pop * pop_n
            )
            if hybrid <= 0 and not interacted:
                # Pure cold-start: popularity alone is enough to rank.
                hybrid = pop_n * self.w_pop + 0.05

            reason = self._pick_reason(cf_n, content_n, pop_n)
            scored.append(
                {
                    "productId": pid,
                    "score": round(float(hybrid), 6),
                    "reason": reason,
                    "components": {
                        "cf": round(float(cf_n), 4),
                        "content": round(float(content_n), 4),
                        "popularity": round(float(pop_n), 4),
                    },
                }
            )

        scored.sort(key=lambda item: item["score"], reverse=True)

        # Prefer same-category items near the top when user has a clear preference.
        if top_category and category_weights:
            preferred = [
                item
                for item in scored
                if str(products.get(item["productId"], {}).get("category") or "")
                .strip()
                .lower()
                == top_category
            ]
            others = [item for item in scored if item not in preferred]
            # Interleave: keep preferred first but don't drop others.
            scored = preferred + others

        return scored[: self.top_n]

    def _pick_reason(self, cf_n: float, content_n: float, pop_n: float) -> str:
        best = max(
            (cf_n, "similar_to_previous_activity"),
            (content_n, "same_category_preference"),
            (pop_n, "popular_product"),
            key=lambda pair: pair[0],
        )
        if best[0] <= 0.05:
            return "available_product"
        return best[1]

    def _source_label(
        self,
        user_id: str,
        user_index: dict[str, int],
        purchases: list[dict[str, Any]],
        interactions: list[dict[str, Any]],
    ) -> str:
        has_purchase = any(p.get("userId") == user_id for p in purchases)
        has_event = any(e.get("userId") == user_id for e in interactions)
        if has_purchase or has_event:
            return "hybrid"
        return "cold_start"

    def _catalog_fallback(
        self,
        products: dict[str, dict[str, Any]],
        exclude: set[str],
        limit: int,
    ) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
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
        source: str = "hybrid",
    ) -> None:
        # Strip bulky components for Firestore storage size if present is fine to keep for explainability
        slim_items = []
        for item in recommendations:
            slim_items.append(
                {
                    "productId": item["productId"],
                    "score": item["score"],
                    "reason": item.get("reason", "hybrid"),
                }
            )
        ref = self.db.collection("recommendations").document(user_id)
        batch.set(
            ref,
            {
                "userId": user_id,
                "items": slim_items,
                "source": source,
                "model": "hybrid_cf_content_popularity",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )

    def evaluate(
        self,
        purchases: list[dict[str, Any]],
        interactions: list[dict[str, Any]],
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
            return {
                "precisionAtK": 0.0,
                "recallAtK": 0.0,
                "topNAccuracy": 0.0,
                "evaluatedUsers": 0,
            }

        matrix, user_index, product_index = self._build_interaction_matrix(
            train_purchases, interactions, products,
        )
        similarity = self._cosine_similarity(matrix)
        popular_scores = self._popularity_scores(train_purchases, interactions, products)
        category_index = self._build_category_index(products)

        hits = 0
        for user_id, expected_product_id in test_items.items():
            recommended = self._hybrid_recommend(
                user_id,
                train_purchases,
                interactions,
                products,
                matrix,
                user_index,
                product_index,
                similarity,
                popular_scores,
                category_index,
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
        event_count: int = 0,
    ) -> None:
        self.db.collection("recommendation_training_logs").add(
            {
                "trainedAt": datetime.now(timezone.utc),
                "purchaseCount": purchases,
                "eventCount": event_count,
                "userCount": users,
                "recommendationDocs": recommendation_docs,
                "status": status,
                "model": "hybrid_cf_content_popularity",
                "metrics": metrics or {},
            }
        )
