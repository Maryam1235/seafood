# seafood-api

Self-hosted **NestJS** backend for ZanSeaFood. It replaces the Firebase Cloud
Functions (which required the paid Blaze plan) with a server you run on a cheap
always-on VPS. It handles:

- **ClickPesa payments** — hosted-checkout pay-in, escrow release payouts, webhook
- **FCM push notifications** — via a Firestore listener that mirrors the old triggers

Firestore, Firebase Auth, and FCM stay on the **free Spark plan**. This server talks
to them with the Firebase Admin SDK (a service account), which does **not** need Blaze.

## Endpoints

| Method | Path                    | Auth                        | Purpose |
|--------|-------------------------|-----------------------------|---------|
| POST   | `/payments/create`      | Firebase ID token (Bearer)  | Create ClickPesa checkout link → `{ paymentUrl }` |
| POST   | `/payments/release`     | Firebase ID token (Bearer)  | Release escrow → seller + driver payouts |
| POST   | `/webhooks/clickpesa`   | none (verified by re-query) | ClickPesa payment-status callback |

> **Webhook security:** ClickPesa webhooks carry no auth header. Instead of trusting the
> body, the server uses the webhook only as a trigger and re-queries
> `GET /third-parties/payments/{orderReference}` (authenticated with our JWT) to get the
> real status before moving money. A spoofed webhook can't fake ClickPesa's own API.

## Local development

1. `npm install`
2. Download a service-account key: Firebase console → Project **testing-bc269** →
   Project settings → Service accounts → **Generate new private key**. Save it as
   `serviceAccountKey.json` in this folder (it is gitignored).
3. `cp .env.example .env` and fill in `CLICKPESA_CLIENT_ID`, `CLICKPESA_API_KEY`,
   `CLICKPESA_WEBHOOK_SECRET`.
4. `npm run start:dev`
5. Point the Flutter app at it:
   `flutter run --dart-define=API_BASE_URL=http://<your-LAN-ip>:3000`
   (use your machine's LAN IP, not `localhost`, when testing on a physical phone).

## Deploy to a VPS (~$5/mo, always-on, fixed IP)

Chosen over serverless because ClickPesa can require **IP whitelisting** — a VPS has a
stable IP.

```bash
# On the VPS (Ubuntu, Node 20):
git clone <repo> && cd seafood/seafood-api
npm ci
npm run build
# put serviceAccountKey.json and .env on the box (never commit them)
sudo npm i -g pm2
pm2 start dist/main.js --name seafood-api
pm2 save && pm2 startup    # restart on reboot
```

### HTTPS (required for the ClickPesa webhook) — Caddy

ClickPesa only calls HTTPS URLs. Caddy gives automatic Let's Encrypt certs:

```
# /etc/caddy/Caddyfile
api.your-domain.com {
    reverse_proxy localhost:3000
}
```

Open ports 80/443 in the firewall; keep port 3000 internal.

## ClickPesa dashboard configuration

1. **IP whitelist** → add the VPS's public IP.
2. **Webhooks** → point every event (PAYMENT RECEIVED, PAYMENT FAILED, PAYOUT …) at
   `https://api.your-domain.com/webhooks/clickpesa` (or `http://<ip>/webhooks/clickpesa`
   for a quick test). No header is needed — the server verifies each event by re-querying
   ClickPesa's API.
3. **Hosted-checkout Return URL** → the page/deep link the customer lands on after paying.

## Verify

```bash
# Auth guard rejects missing token:
curl -i -X POST https://api.your-domain.com/payments/create -d '{"orderId":"x"}'   # → 401

# Webhook for an unknown order → 404 (a spoofed SUCCESS can't take effect because
# the server re-queries ClickPesa for the real status before acting):
curl -i -X POST https://api.your-domain.com/webhooks/clickpesa \
  -H 'Content-Type: application/json' \
  -d '{"event":"PAYMENT RECEIVED","data":{"orderReference":"x","status":"SUCCESS"}}'  # → 404
```

End-to-end: place an order in the app → pay via the checkout link → webhook flips the
order to `held_in_escrow` → "Confirm Receipt" → seller + driver receive payouts →
order marked `released`/`delivered`. If a payout fails, funds stay in escrow.
