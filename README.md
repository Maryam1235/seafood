# ZanSeaFood

ZanSeaFood is a seafood marketplace system for customers, sellers, drivers, and administrators.

This repository is organized as a monorepo: the mobile app, admin panel, payment API, recommendation service, Firebase functions, and documentation live together, but each service can still be deployed separately.

## Project Structure

```text
seafood/
├── app/                         # Flutter mobile app
├── react_admin/                 # React + Vite admin panel
├── seafood-api/                 # NestJS API for ClickPesa, FCM, and backend workflows
├── recommendation-service/      # Python FastAPI recommendation engine
├── functions/                   # Firebase Cloud Functions, if still needed
├── SYSTEM_DOCUMENTATION.md      # Full system documentation
├── RECOMMENDATION_SYSTEM.md     # Recommendation architecture notes
└── FIREBASE_SETUP.md            # Firebase setup notes
```

## Services

| Service | Path | Runtime | Purpose |
|---|---|---|---|
| Mobile app | `app/` | Flutter/Dart | Customer, seller, and driver app |
| Admin panel | `react_admin/` | React + Vite | Admin dashboard |
| API | `seafood-api/` | NestJS/Node.js | ClickPesa payments, FCM notifications, purchase-history writes |
| Recommendation service | `recommendation-service/` | FastAPI/Python | Trains recommendations and writes them to Firestore |
| Firebase functions | `functions/` | Node.js | Legacy or auxiliary Firebase functions |

## Local Development

### Mobile App

```bash
cd app
flutter pub get
flutter run
```

By default, the app talks to `https://api.arifa.org`. For local API testing:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:3000
```

### Admin Panel

```bash
cd react_admin
npm install
npm run dev
```

### NestJS API

```bash
cd seafood-api
npm install
cp .env.example .env
npm run start:dev
```

The API expects Firebase Admin credentials and ClickPesa credentials. Keep `.env` and service-account files out of git.

### Recommendation Service

```bash
cd recommendation-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Train manually:

```bash
curl -X POST http://localhost:8000/train
```

## Deployment Model

Keep one GitHub repo for project tracking, but deploy services independently:

| Deployment | Source |
|---|---|
| `api.arifa.org` | `seafood-api/` |
| `recommendations.arifa.org` | `recommendation-service/` |
| Admin panel hosting | `react_admin/` |
| Mobile app builds | `app/` |

`seafood-api` can notify the recommendation service using `RECOMMENDATION_SERVICE_URL`.

## Security Notes

Never commit real `.env` files, Firebase service-account keys, private keys, or production secrets.

If a real service account has already been committed, rotate that key in Firebase and remove the committed file from git history before pushing publicly.
