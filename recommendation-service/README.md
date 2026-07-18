# ZanSeaFood Recommendation Service

Python FastAPI service for item-based collaborative filtering recommendations.

## What It Does

- Reads `purchase_history` from Firestore.
- Builds a user-product matrix from historical purchases.
- Computes item-to-item similarity using cosine similarity.
- Generates top-N product recommendations for each user.
- Saves recommendations to `recommendations/{userId}` in Firestore.
- Provides `GET /recommendations/{userId}`, `POST /train`, and `POST /events/purchase`.
- Falls back to popular/trending available products for cold-start users.

## Firestore Collections

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
    { "productId": "p001", "score": 0.92, "reason": "similar_to_previous_purchases" }
  ],
  "source": "collaborative_filtering",
  "updatedAt": "server timestamp"
}
```

`recommendation_training_logs` stores each training run, purchase count, user count,
and simple evaluation metrics.

## Setup

```bash
cd recommendation-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Set:

```bash
GOOGLE_APPLICATION_CREDENTIALS=../seafood-api/serviceAccountKey.json
```

Run:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Train manually:

```bash
curl -X POST http://localhost:8000/train
```

Notify the service after a successful purchase:

```bash
curl -X POST http://localhost:8000/events/purchase \
  -H 'Content-Type: application/json' \
  -d '{"orderId":"ORDER_ID"}'
```

Purchase events schedule background training after `PURCHASE_TRAINING_DELAY_SECONDS`.
Repeated purchase events inside that delay window are debounced into one training run.

Train from CLI/cron:

```bash
python -m app.train
```

Get recommendations:

```bash
curl http://localhost:8000/recommendations/USER_ID
```

## NestJS Integration

NestJS remains responsible for payments **and** for recording purchase history
on pickup. After ClickPesa verifies a successful payment (or the app calls
`POST /recommendations/record-purchase` for pickup), NestJS writes each purchased
product into `purchase_history`, then calls the Python service `/events/purchase`.
The recommendation service accepts the event quickly and schedules background
training; it does not block the payment webhook while training runs.

Set on NestJS:

```bash
RECOMMENDATION_SERVICE_URL=http://localhost:8000
# production example: https://recommendations.arifa.org
```

Recommended production setup:

```text
api.arifa.org                 -> NestJS seafood-api
recommendations.arifa.org     -> Python FastAPI service
```

Both can run on the same VPS as separate PM2/systemd processes.

## Evaluation

The service logs:

- `precisionAtK`
- `recallAtK`
- `topNAccuracy`
- number of evaluated users
- number of purchase records used

The evaluation uses a simple leave-last-purchase-out strategy per user.

## University Defense Summary

Collaborative filtering recommends products based on patterns in user behavior.
In this project, users who bought similar seafood products help the system infer
which other products may be relevant. The model does not need manual rules for
every product; it learns from purchase history.

Python is used because it has strong data-science libraries and is well suited
for matrix operations and machine-learning workflows. NestJS remains separate
because payments require stable API handling, authentication, and ClickPesa
verification, not ML computation.

Firebase stores users, products, orders, purchase history, and generated
recommendations. Each successful payment creates purchase-history records. As
more purchases are added, the recommendation model has more user-product
interactions and can generate better recommendations.

Companies such as Amazon, Netflix, Spotify, and YouTube use similar recommender
system ideas to personalize products, movies, music, and videos based on user
behavior.
