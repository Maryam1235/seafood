/**
 * ZanSeaFood — Firebase Cloud Functions
 *
 * Architecture:
 *   Flutter app writes to Firestore
 *       ↓
 *   Cloud Function triggers on Firestore event
 *       ↓
 *   Firebase Admin SDK calls FCM HTTP v1 API (service account — never exposed to app)
 *       ↓
 *   Phone receives popup notification even when app is closed
 *
 * Deploy:  firebase deploy --only functions
 * Logs:    firebase functions:log
 *
 * Requires: Blaze (pay-as-you-go) plan on Firebase
 */

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp }  = require('firebase-admin/app');
const { getFirestore }   = require('firebase-admin/firestore');
const { getMessaging }   = require('firebase-admin/messaging');
const axios = require('axios');

initializeApp();  // Uses the service account automatically — no key in code

const db  = getFirestore();
const fcm = getMessaging();

// ─────────────────────────────────────────────────────────────────────────────
// Helper: get FCM device token for a user
// ─────────────────────────────────────────────────────────────────────────────
async function getToken(uid) {
  if (!uid) return null;
  try {
    const snap = await db.collection('users').doc(uid).get();
    return snap.exists ? (snap.data().fcmToken || null) : null;
  } catch (e) {
    console.error(`getToken(${uid}) error:`, e.message);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: send push via FCM HTTP v1 API (Admin SDK handles auth automatically)
// ─────────────────────────────────────────────────────────────────────────────
async function sendPush({ token, title, body, data = {} }) {
  if (!token) {
    console.log('sendPush: no token, skipping');
    return;
  }

  const message = {
    token,
    notification: { title, body },

    // Android — high priority so it wakes the screen
    android: {
      priority: 'high',
      notification: {
        channelId: 'zanseafood_orders',
        sound: 'default',
        priority: 'high',
        defaultVibrateTimings: true,
        visibility: 'PUBLIC',
      },
    },

    // iOS
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          contentAvailable: true,
        },
      },
    },

    // Data payload — Flutter app can read this on tap
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
  };

  try {
    const result = await fcm.send(message);
    console.log('Push sent successfully:', result);
  } catch (err) {
    // Token may be stale — log but don't crash the function
    console.error('Push failed:', err.code, err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: write in-app notification to Firestore
// ─────────────────────────────────────────────────────────────────────────────
async function storeNotification({ userId, type, title, body, orderId, extra = {} }) {
  await db.collection('notifications').add({
    userId,
    type,
    title,
    body,
    orderId,
    read: false,
    createdAt: new Date(),
    ...extra,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 1 — New order created → notify each seller whose items are in the order
// ─────────────────────────────────────────────────────────────────────────────
exports.onNewOrder = onDocumentCreated(
  { document: 'orders/{orderId}', region: 'us-central1' },
  async (event) => {
    const order   = event.data.data();
    const orderId = event.params.orderId;
    const items   = order.items || [];

    // Collect unique seller IDs from the order items
    const sellerIds = [...new Set(
      items.map(i => i.sellerId).filter(Boolean)
    )];

    if (sellerIds.length === 0) {
      console.log('onNewOrder: no sellers found in order', orderId);
      return;
    }

    // Resolve customer name
    let customerName = 'A customer';
    if (order.customerId) {
      const custSnap = await db.collection('users').doc(order.customerId).get();
      if (custSnap.exists) {
        const d = custSnap.data();
        customerName = d.fullName || d.username || 'A customer';
      }
    }

    // Notify each seller
    await Promise.all(sellerIds.map(async (sellerId) => {
      const sellerItems = items.filter(i => i.sellerId === sellerId);
      const subtotal = sellerItems.reduce(
        (sum, i) => sum + ((i.price || 0) * (i.quantity || 1)), 0
      );

      const title = 'New Order Received 🛒';
      const body  = `${customerName} ordered ${sellerItems.length} item${sellerItems.length > 1 ? 's' : ''} — TShs ${subtotal.toFixed(0)}`;

      // 1. In-app notification (shows in bell icon inside app)
      await storeNotification({
        userId: sellerId,
        type: 'new_order',
        title,
        body,
        orderId,
        extra: { customerName, itemCount: String(sellerItems.length) },
      });

      // 2. Real push notification (shows on phone even when app is closed)
      const token = await getToken(sellerId);
      await sendPush({
        token,
        title,
        body,
        data: { orderId, type: 'new_order', customerName },
      });
    }));
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER 2 — Order updated → handle all status transitions
// ─────────────────────────────────────────────────────────────────────────────
exports.onOrderUpdated = onDocumentUpdated(
  { document: 'orders/{orderId}', region: 'us-central1' },
  async (event) => {
    const before  = event.data.before.data();
    const after   = event.data.after.data();
    const orderId = event.params.orderId;

    const statusBefore = before.status;
    const statusAfter  = after.status;
    const customerId   = after.customerId;

    // ── 2a. pending → confirmed (seller confirmed) → notify customer ──────────
    if (statusBefore === 'pending' && statusAfter === 'confirmed') {
      const title = 'Order Confirmed ✅';
      const body  = 'Your order has been confirmed by the seller. Please choose how you want to receive it.';

      await storeNotification({
        userId: customerId, type: 'order_status',
        title, body, orderId,
        extra: { status: 'confirmed' },
      });

      const token = await getToken(customerId);
      await sendPush({
        token, title, body,
        data: { orderId, type: 'order_status', status: 'confirmed' },
      });
    }

    // ── 2b. any → cancelled (seller cancelled) → notify customer ─────────────
    if (statusBefore !== 'cancelled' && statusAfter === 'cancelled') {
      // Get seller name for the message
      let sellerName = 'the seller';
      const items = after.items || [];
      const sellerIds = [...new Set(items.map(i => i.sellerId).filter(Boolean))];
      if (sellerIds.length > 0) {
        const sellerSnap = await db.collection('users').doc(sellerIds[0]).get();
        if (sellerSnap.exists) {
          const d = sellerSnap.data();
          sellerName = d.fullName || d.username || 'the seller';
        }
      }

      const title = 'Order Cancelled ❌';
      const body  = `Sorry, your order was cancelled by ${sellerName}.`;

      await storeNotification({
        userId: customerId, type: 'order_status',
        title, body, orderId,
        extra: { status: 'cancelled' },
      });

      const token = await getToken(customerId);
      await sendPush({
        token, title, body,
        data: { orderId, type: 'order_status', status: 'cancelled' },
      });
    }

    // ── 2c. any → delivered (driver delivered) → notify customer ─────────────
    if (statusBefore !== 'delivered' && statusAfter === 'delivered') {
      const title = 'Order Delivered 🎉';
      const body  = 'Your seafood order has been delivered. Enjoy your meal!';

      await storeNotification({
        userId: customerId, type: 'order_status',
        title, body, orderId,
        extra: { status: 'delivered' },
      });

      const token = await getToken(customerId);
      await sendPush({
        token, title, body,
        data: { orderId, type: 'order_status', status: 'delivered' },
      });
    }

    // ── 2d. driver assigned → notify driver ───────────────────────────────────
    const driverBefore = before.delivery?.driverId;
    const driverAfter  = after.delivery?.driverId;

    if (!driverBefore && driverAfter) {
      let customerName = 'A customer';
      if (customerId) {
        const custSnap = await db.collection('users').doc(customerId).get();
        if (custSnap.exists) {
          const d = custSnap.data();
          customerName = d.fullName || d.username || 'A customer';
        }
      }

      const deliveryCost = after.delivery?.cost || 0;
      const vehicleType  = after.delivery?.vehicleType || '';
      const title = 'New Delivery Request 🚀';
      const body  = `New delivery from ${customerName}. Delivery fee: TShs ${deliveryCost}`;

      await storeNotification({
        userId: driverAfter, type: 'new_delivery',
        title, body, orderId,
        extra: { vehicleType, customerName },
      });

      const token = await getToken(driverAfter);
      await sendPush({
        token, title, body,
        data: { orderId, type: 'new_delivery', vehicleType, customerName },
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CLICKPESA INTEGRATION
// ─────────────────────────────────────────────────────────────────────────────

// ClickPesa credentials — stored in Google Secret Manager, never in source.
//   Set them with:
//     firebase functions:secrets:set CLICKPESA_CLIENT_ID
//     firebase functions:secrets:set CLICKPESA_API_KEY
//     firebase functions:secrets:set CLICKPESA_WEBHOOK_SECRET   (optional, see webhook)
const CLICKPESA_CLIENT_ID     = defineSecret('CLICKPESA_CLIENT_ID');
const CLICKPESA_API_KEY       = defineSecret('CLICKPESA_API_KEY');
const CLICKPESA_WEBHOOK_SECRET = defineSecret('CLICKPESA_WEBHOOK_SECRET');

const CLICKPESA_API_URL = 'https://api.clickpesa.com/third-parties';

// ─────────────────────────────────────────────────────────────────────────────
// ClickPesa auth — exchange client-id + api-key for a short-lived JWT.
// The token is valid ~1 hour, so we cache it in memory across warm invocations
// and refresh a minute before expiry.
// https://docs.clickpesa.com/api-reference/authorization/generate-token
// ─────────────────────────────────────────────────────────────────────────────
let cachedToken = null;      // { value, expiresAt }

async function getClickPesaToken() {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now) {
    return cachedToken.value;
  }

  const res = await axios.post(
    `${CLICKPESA_API_URL}/generate-token`,
    {},
    {
      headers: {
        'client-id': CLICKPESA_CLIENT_ID.value(),
        'api-key': CLICKPESA_API_KEY.value(),
      },
    }
  );

  const token = res.data?.token;
  if (!res.data?.success || !token) {
    throw new Error(`ClickPesa token generation failed: ${JSON.stringify(res.data)}`);
  }

  // Token lives ~1h; cache for 55 min to stay safely inside the window.
  cachedToken = { value: token, expiresAt: now + 55 * 60 * 1000 };
  return token;
}

// Build authorized headers for a ClickPesa API call.
async function clickPesaAuthHeaders() {
  const token = await getClickPesaToken();
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

const CLICKPESA_SECRETS = [CLICKPESA_CLIENT_ID, CLICKPESA_API_KEY];

/**
 * 1. createClickPesaPayment (Pay-In)
 * Called by the Customer from the Flutter App to initiate a payment.
 * Uses ClickPesa Hosted Checkout Link generation.
 */
exports.createClickPesaPayment = onCall(
  { region: 'us-central1', secrets: CLICKPESA_SECRETS },
  async (request) => {
    const { orderId } = request.data;
    const uid = request.auth?.uid;

    if (!uid || !orderId) {
      throw new HttpsError('invalid-argument', 'Missing uid or orderId');
    }

    // Get Order details
    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'Order not found');
    }

    const order = orderSnap.data();
    if (order.customerId !== uid) {
      throw new HttpsError('permission-denied', 'Not your order');
    }

    // Call ClickPesa API to create a checkout link
    // https://docs.clickpesa.com/api-reference/collection/generate-checkout-link/generate-checkout-link
    const payload = {
      totalPrice: String(order.grandTotal), // ClickPesa expects string for checkout
      orderReference: orderId,               // Our order ID
      orderCurrency: 'TZS',
      description: `ZanSeaFood Order ${orderId}`,
      customerName: order.customerName || 'ZanSeaFood Customer',
    };

    // Add phone if available (ClickPesa requires no plus sign)
    if (order.phoneNumber) {
      payload.customerPhone = order.phoneNumber.replace('+', '');
    }

    let paymentUrl;
    try {
      const headers = await clickPesaAuthHeaders();
      const response = await axios.post(
        `${CLICKPESA_API_URL}/checkout-link/generate-checkout-url`,
        payload,
        { headers }
      );
      paymentUrl = response.data?.checkoutLink;
    } catch (apiErr) {
      console.error('ClickPesa checkout-link error:', apiErr.response?.data || apiErr.message);
      throw new HttpsError('unavailable', 'Could not reach the payment provider. Please try again.');
    }

    if (!paymentUrl) {
      throw new HttpsError('internal', 'Payment provider did not return a checkout link.');
    }

    // Mark the order as awaiting payment. It only moves to escrow once the
    // ClickPesa webhook confirms the money was actually received.
    await orderRef.update({
      paymentMethod: 'clickpesa',
      paymentStatus: 'pending',
    });

    return { success: true, paymentUrl };
  }
);

/**
 * 2. clickPesaWebhook
 * Receives Webhook from ClickPesa when the payment status changes.
 * Only a verified SUCCESS moves the order into escrow.
 *
 * Security: ClickPesa signs webhooks. Set CLICKPESA_WEBHOOK_SECRET and this
 * function rejects any request that does not carry the matching secret in the
 * `x-webhook-secret` header (configure the header in your ClickPesa dashboard).
 * If no secret is configured the request is refused outright — fail closed.
 */
exports.clickPesaWebhook = onRequest(
  { region: 'us-central1', secrets: [CLICKPESA_WEBHOOK_SECRET] },
  async (req, res) => {
    const expectedSecret = CLICKPESA_WEBHOOK_SECRET.value();
    const providedSecret = req.get('x-webhook-secret');

    if (!expectedSecret || providedSecret !== expectedSecret) {
      console.warn('clickPesaWebhook: rejected unverified request');
      return res.status(401).send('Unauthorized');
    }

    const data = req.body || {};
    const orderId = data.orderReference || data.reference;
    const status = data.status; // e.g. 'SUCCESS', 'FAILED'

    if (!orderId) {
      return res.status(400).send('No order reference provided');
    }

    try {
      const orderRef = db.collection('orders').doc(orderId);
      const orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        console.warn(`clickPesaWebhook: order ${orderId} not found`);
        return res.status(404).send('Order not found');
      }

      const normalized = String(status || '').toUpperCase();
      if (normalized === 'SUCCESS' || normalized === 'COMPLETED' || normalized === 'SUCCESSFUL') {
        // Idempotent: don't reprocess an order already in/through escrow.
        const current = orderSnap.data().paymentStatus;
        if (current !== 'held_in_escrow' && current !== 'released') {
          await orderRef.update({
            paymentStatus: 'held_in_escrow',
            status: 'confirmed', // Confirm order so the seller/driver can proceed
            clickPesaPayInRef: data.id || data.transactionId || data.transaction_id || null,
          });
        }
      } else {
        await orderRef.update({ paymentStatus: 'failed' });
      }

      res.status(200).send('OK');
    } catch (error) {
      console.error('Webhook processing error:', error);
      res.status(500).send('Internal Server Error');
    }
  }
);

/**
 * 3. releaseEscrow (Pay-Out)
 * Called when the Customer clicks "Confirm Receipt" in the app.
 * Triggers mobile money payouts to the Seller (for food) and the Driver (for delivery).
 * The order is only marked 'released' if every required payout actually succeeds.
 */
exports.releaseEscrow = onCall(
  { region: 'us-central1', secrets: CLICKPESA_SECRETS },
  async (request) => {
    const { orderId } = request.data;
    const uid = request.auth?.uid;

    if (!uid || !orderId) {
      throw new HttpsError('invalid-argument', 'Missing uid or orderId');
    }

    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'Order not found');
    }

    const order = orderSnap.data();
    if (order.customerId !== uid) {
      throw new HttpsError('permission-denied', 'Not your order');
    }

    if (order.paymentStatus !== 'held_in_escrow') {
      throw new HttpsError('failed-precondition', 'Payment is not in escrow');
    }

    // Calculate payouts
    const productTotal = order.total || 0;
    const deliveryFee = order.delivery?.cost || 0;

    // We need to know who to pay
    const sellerId = order.items?.[0]?.sellerId; // Assuming 1 seller per order for simplicity
    const driverId = order.delivery?.driverId;

    // Process an individual Mobile Money Payout. Returns true on success.
    // Throws if the recipient has no payout phone on file, so we don't
    // silently skip paying someone who is owed money.
    // https://docs.clickpesa.com/api-reference/disbursement/mno-payout/create-mno-payout
    const processPayout = async (userId, amount, referenceSuffix) => {
      if (!userId || amount <= 0) return; // nothing owed to this party

      const userSnap = await db.collection('users').doc(userId).get();
      const payoutDetails = userSnap.data()?.payoutDetails;
      const mobilePayment = userSnap.data()?.mobilePayment;
      let phone = payoutDetails?.accountNumber || mobilePayment;

      if (!phone) {
        throw new HttpsError(
          'failed-precondition',
          `Recipient (${referenceSuffix}) has no mobile-money number on file.`
        );
      }

      phone = phone.replace('+', '');
      const payoutPayload = {
        amount: Number(amount), // ClickPesa expects a number for payouts
        orderReference: `${orderId}_${referenceSuffix}`,
        phoneNumber: phone,
        currency: 'TZS',
      };

      const headers = await clickPesaAuthHeaders();
      const response = await axios.post(
        `${CLICKPESA_API_URL}/payouts/create-mobile-money-payout`,
        payoutPayload,
        { headers }
      );
      console.log(
        `ClickPesa payout to ${referenceSuffix} (${userId}) accepted for TZS ${amount}:`,
        response.data?.id || response.data?.status || 'OK'
      );
    };

    try {
      // 1. Payout to Seller
      await processPayout(sellerId, productTotal, 'seller');

      // 2. Payout to Driver
      await processPayout(driverId, deliveryFee, 'driver');
    } catch (error) {
      // A payout failed — leave the funds in escrow so nothing is lost and the
      // customer can retry / support can intervene.
      console.error('Error releasing escrow:', error.response?.data || error.message || error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Failed to release funds via ClickPesa. Funds remain in escrow.');
    }

    // Only now, after both payouts succeeded, mark the order complete.
    await orderRef.update({
      paymentStatus: 'released',
      status: 'delivered',
      customerConfirmedReceipt: true,
    });

    return { success: true };
  }
);
