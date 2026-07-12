# ZanSeaFood Recommendation System

## Architecture

```text
Flutter app
  reads recommendations from Firestore

Firebase / Firestore
  users
  products
  orders
  purchase_history
  recommendations
  recommendation_training_logs

NestJS seafood-api
  verifies ClickPesa payments
  writes purchase_history after successful payment verification
  optionally notifies Python recommendation service

Python FastAPI recommendation-service
  trains item-based collaborative filtering
  writes recommendations back to Firestore
```

The Python service lives in `recommendation-service/` inside this monorepo. It is
hosted separately from NestJS. They can run on the same VPS, but as separate
processes.

## Firestore Data Model

`purchase_history/{orderId_productId}`:

```json
{
  "userId": "abc123",
  "productId": "p001",
  "quantity": 2,
  "price": 15000,
  "category": "fish",
  "purchaseDate": "server timestamp",
  "orderId": "order123"
}
```

`recommendations/{userId}`:

```json
{
  "userId": "abc123",
  "items": [
    {
      "productId": "p001",
      "score": 0.92,
      "reason": "similar_to_previous_purchases"
    }
  ],
  "source": "collaborative_filtering",
  "updatedAt": "server timestamp"
}
```

## Training Flow

1. Customer pays using ClickPesa.
2. ClickPesa webhook reaches NestJS.
3. NestJS verifies payment status directly with ClickPesa.
4. If payment is `SUCCESS` or `SETTLED`, NestJS marks the order as confirmed.
5. NestJS writes each purchased product to `purchase_history`.
6. Python service trains daily, or manually through `POST /train`.
7. Python service writes top recommendations to Firestore.
8. Flutter reads Firestore and displays recommended seafood products.

## Collaborative Filtering

The service uses item-based collaborative filtering:

1. Build a user-product matrix from purchase quantities.
2. Treat each product as a vector of user interactions.
3. Calculate product-to-product cosine similarity.
4. For each user, recommend products similar to products they already bought.
5. Exclude already purchased products unless the product has `repeatBuy: true`.

## Cold Start

If a user has no purchase history, the service recommends:

- popular products from purchase history
- available products with stock
- products matching `users/{uid}.preferredCategory` or `categoryPreference` when present

## Evaluation

Each training run writes a document to `recommendation_training_logs` with:

- purchase count
- user count
- recommendation document count
- Precision@K
- Recall@K
- Top-N accuracy

The current evaluation uses a simple leave-last-purchase-out method.

## API

Python service:

```http
GET /health
POST /train
POST /events/purchase
GET /recommendations/{userId}
```

Example:

```json
{
  "userId": "abc123",
  "recommendations": [
    {
      "productId": "p001",
      "score": 0.92
    },
    {
      "productId": "p005",
      "score": 0.87
    }
  ]
}
```

## University Defense Explanation

Collaborative filtering is a recommendation technique that uses user behavior to
suggest items. In ZanSeaFood, the system looks at historical seafood purchases.
If customers who bought tuna also commonly bought prawns, the model can recommend
prawns to another tuna buyer.

Python was used for the recommendation engine because it is strong for data
processing, matrix calculations, and machine-learning workflows. NestJS was kept
for payments because payment verification needs secure API handling, Firebase
authentication, and ClickPesa integration, not machine-learning computation.

Firebase stores the operational data: users, products, orders, purchase history,
and generated recommendations. After a successful payment, NestJS writes the
purchased products to `purchase_history`. As more purchases are recorded, the
Python service has more interaction data and the recommendations improve.

Large companies use similar ideas. Amazon recommends products, Netflix
recommends movies, Spotify recommends music, and YouTube recommends videos based
on behavior patterns from many users.
