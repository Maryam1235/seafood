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

1. Customer places an order (delivery + ClickPesa, or free pickup).
2. **Delivery path:** ClickPesa webhook reaches NestJS → payment verified →
   order confirmed → NestJS writes `purchase_history`.
3. **Pickup path:** Flutter confirms pickup, then calls NestJS
   `POST /recommendations/record-purchase` so `purchase_history` is written
   even without ClickPesa.
4. NestJS notifies the Python service (`POST /events/purchase`) when
   `RECOMMENDATION_SERVICE_URL` is set.
5. Python trains on startup, daily, after purchase events, or via `POST /train`.
6. Python writes top recommendations to `recommendations/{userId}` for
   purchasers **and** other customers (cold start / popular / catalog fill).
7. Flutter reads Firestore and displays recommended seafood products. If the
   rec doc is missing or all items are unavailable, Flutter falls back to
   available products so the section is not blank.

## Hybrid model (CF + content + popularity)

The service uses a **hybrid recommender**, closer to professional e-commerce stacks
than pure purchase CF alone:

1. **Signals**
   - Purchases (`purchase_history`) — weight 5
   - Add to cart (`user_interactions`, type `add_to_cart`) — weight 3.5
   - Clicks (`click`) — weight 2
   - Views (`view`) — weight 1
2. **Collaborative filtering** — item–item cosine similarity on the combined
   implicit-feedback matrix.
3. **Content affinity** — boost products in categories the user bought/viewed
   (and `preferredCategory` / `categoryPreference` on the user profile).
4. **Popularity prior** — products with more purchases/interactions rank higher
   when personal signal is weak.
5. **Hybrid score** (configurable via env):

   ```text
   score = W_CF * cf + W_CONTENT * content + W_POP * popularity
   ```

   Defaults: `W_CF=0.45`, `W_CONTENT=0.35`, `W_POP=0.20`.

6. Exclude already-interacted products unless `repeatBuy: true`.
7. Always fall back to available catalog products so the UI is never empty.

Flutter logs interactions via `RecommendationEventService` into
`user_interactions`. Training also runs after purchase events and (debounced)
interaction events.

## Cold Start

If a user has little or no history, the service still recommends:

- popular products (purchases + interactions)
- same-category products when a preference is known
- available products with stock
- products matching `users/{uid}.preferredCategory` or `categoryPreference`

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

NestJS (`seafood-api`, authenticated with Firebase ID token):

```http
POST /recommendations/record-purchase
Body: { "orderId": "..." }
```

Records `purchase_history` for a confirmed / pickup order owned by the caller,
then notifies the Python service.

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
