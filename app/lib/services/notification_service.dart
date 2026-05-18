/**
 * NotificationService — Flutter side
 *
 * Responsibilities:
 *   1. Request notification permission from the device
 *   2. Save the FCM device token to Firestore so Cloud Functions can send pushes
 *   3. Handle foreground/background message events
 *
 * What this does NOT do:
 *   - Does NOT call FCM API directly
 *   - Does NOT hold any server key or service account credentials
 *   - Does NOT send push notifications itself
 *
 * Push notifications are sent by Firebase Cloud Functions (functions/index.js)
 * which run securely on Google's servers using the Firebase Admin SDK.
 */

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Must be a top-level function — called when app is in background/terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase SDK automatically shows the notification popup.
  // Nothing extra needed here unless you want custom handling.
  debugPrint('Background push received: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  // ── Call once in main.dart before runApp ────────────────────────────────────
  static Future<void> init() async {
    // Register background handler FIRST
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Ask the user for notification permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // Show notification banner even when app is open (foreground)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Save this device's token so Cloud Functions know where to send pushes
    await saveFcmToken();

    // Keep token fresh — Firebase rotates tokens occasionally
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed');
      _saveToken(newToken);
    });

    // App is open and a push arrives — log it (banner is shown automatically)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'Foreground push: ${message.notification?.title} — ${message.notification?.body}',
      );
    });

    // User tapped a notification while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tapped (background): ${message.data}');
      // TODO: navigate to the relevant order screen based on message.data['orderId']
    });

    // App was fully closed and user tapped the notification to open it
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from notification: ${initialMessage.data}');
      // TODO: navigate to the relevant order screen
    }
  }

  // ── Save FCM token to Firestore ─────────────────────────────────────────────
  // Cloud Functions read this token to know which device to send the push to.
  static Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
      debugPrint('FCM token saved for user $uid');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  // ── These methods write in-app notifications to Firestore ───────────────────
  // The Cloud Function (onNewOrder / onOrderUpdated) also sends the real push.
  // These are called from the app to ensure the in-app bell shows immediately.

  static Future<void> sendNewOrderNotification({
    required String sellerId,
    required String orderId,
    required String customerName,
    required int itemCount,
    required double subtotal,
  }) async {
    // Cloud Function handles the push. We just write the in-app notification
    // here so the seller's bell badge updates instantly inside the app.
    await _db.collection('notifications').add({
      'userId': sellerId,
      'type': 'new_order',
      'title': 'New Order Received 🛒',
      'body':
          '$customerName ordered $itemCount item${itemCount > 1 ? 's' : ''} — TShs ${subtotal.toStringAsFixed(0)}',
      'orderId': orderId,
      'customerName': customerName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendOrderConfirmationNotification({
    required String customerId,
    required String orderId,
    required bool confirmed,
    String? sellerName,
  }) async {
    // Cloud Function handles the push automatically when order.status changes.
    // This writes the in-app notification for immediate bell badge update.
    await _db.collection('notifications').add({
      'userId': customerId,
      'type': 'order_status',
      'title': confirmed ? 'Order Confirmed ✅' : 'Order Cancelled ❌',
      'body': confirmed
          ? 'Your order has been confirmed. Please choose how you want to receive it.'
          : 'Sorry, your order was cancelled${sellerName != null ? ' by $sellerName' : ''}.',
      'orderId': orderId,
      'status': confirmed ? 'confirmed' : 'cancelled',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendDeliveryNotification({
    required String driverId,
    required String orderId,
    required String customerName,
    required String orderTotal,
    required String vehicleType,
  }) async {
    await _db.collection('notifications').add({
      'userId': driverId,
      'type': 'new_delivery',
      'title': 'New Delivery Request 🚀',
      'body': 'New delivery from $customerName. Fee: TShs $orderTotal',
      'orderId': orderId,
      'vehicleType': vehicleType,
      'customerName': customerName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendOrderStatusNotification({
    required String customerId,
    required String orderId,
    required String status,
  }) async {
    String title, body;
    switch (status) {
      case 'delivered':
        title = 'Order Delivered 🎉';
        body = 'Your seafood order has been delivered. Enjoy!';
        break;
      case 'cancelled':
        title = 'Order Cancelled ❌';
        body = 'Your order has been cancelled.';
        break;
      default:
        title = 'Order Update';
        body = 'Your order status: $status';
    }

    await _db.collection('notifications').add({
      'userId': customerId,
      'type': 'order_status',
      'title': title,
      'body': body,
      'orderId': orderId,
      'status': status,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
