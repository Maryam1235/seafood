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
const { initializeApp }  = require('firebase-admin/app');
const { getFirestore }   = require('firebase-admin/firestore');
const { getMessaging }   = require('firebase-admin/messaging');

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
