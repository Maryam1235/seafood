import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Background message handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  // ── Init ────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Set foreground notification presentation options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await saveFcmToken();

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    // Show foreground messages as snackbar/notification
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'Foreground: ${message.notification?.title} — ${message.notification?.body}',
      );
    });
  }

  // ── Token management ────────────────────────────────────────────────────────
  static Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  // ── Core: send FCM push via HTTP v1 API ─────────────────────────────────────
  // Uses the FCM legacy HTTP API with the server key stored in Firestore settings.
  // This allows sending push notifications directly from the app without a server.
  static Future<void> _sendPush({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Fetch server key from Firestore (stored by admin in settings)
      final settingsDoc = await _db.collection('settings').doc('fcm').get();
      final serverKey = settingsDoc.data()?['serverKey'] as String?;
      if (serverKey == null || serverKey.isEmpty) {
        debugPrint('FCM server key not configured in Firestore settings/fcm');
        return;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'priority': 'high',
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'android_channel_id': 'zanseafood_orders',
          },
          'data': {'click_action': 'FLUTTER_NOTIFICATION_CLICK', ...?data},
        }),
      );

      debugPrint('FCM response: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('FCM push error: $e');
    }
  }

  // ── Get recipient FCM token ─────────────────────────────────────────────────
  static Future<String?> _getToken(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['fcmToken'] as String?;
  }

  // ── Store notification in Firestore (in-app) ────────────────────────────────
  static Future<void> _storeNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String orderId,
    String? status,
    String? vehicleType,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'orderId': orderId,
      if (status != null) 'status': status,
      if (vehicleType != null) 'vehicleType': vehicleType,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── PUBLIC: Seller confirmed or cancelled order → notify customer ────────────
  static Future<void> sendOrderConfirmationNotification({
    required String customerId,
    required String orderId,
    required bool confirmed, // true = confirmed, false = cancelled
    String? sellerName,
  }) async {
    final title = confirmed ? 'Order Confirmed ✅' : 'Order Cancelled ❌';
    final body = confirmed
        ? 'Your order has been confirmed by the seller. Please select a delivery driver.'
        : 'Sorry, your order has been cancelled by the seller.${sellerName != null ? ' ($sellerName)' : ''}';

    // 1. Store in Firestore for in-app notification
    await _storeNotification(
      userId: customerId,
      type: 'order_status',
      title: title,
      body: body,
      orderId: orderId,
      status: confirmed ? 'confirmed' : 'cancelled',
    );

    // 2. Send real push notification to device
    final token = await _getToken(customerId);
    if (token != null) {
      await _sendPush(
        fcmToken: token,
        title: title,
        body: body,
        data: {
          'orderId': orderId,
          'type': 'order_status',
          'status': confirmed ? 'confirmed' : 'cancelled',
        },
      );
    }
  }

  // ── PUBLIC: Driver assigned → notify driver ──────────────────────────────────
  static Future<void> sendDeliveryNotification({
    required String driverId,
    required String orderId,
    required String customerName,
    required String orderTotal,
    required String vehicleType,
  }) async {
    const title = 'New Delivery Request 🚀';
    final body = 'New delivery from $customerName. Total: TShs $orderTotal';

    await _storeNotification(
      userId: driverId,
      type: 'new_delivery',
      title: title,
      body: body,
      orderId: orderId,
      vehicleType: vehicleType,
    );

    final token = await _getToken(driverId);
    if (token != null) {
      await _sendPush(
        fcmToken: token,
        title: title,
        body: body,
        data: {
          'orderId': orderId,
          'type': 'new_delivery',
          'vehicleType': vehicleType,
        },
      );
    }
  }

  // ── PUBLIC: Order status update → notify customer ────────────────────────────
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
        body = 'Your order status has been updated to $status';
    }

    await _storeNotification(
      userId: customerId,
      type: 'order_status',
      title: title,
      body: body,
      orderId: orderId,
      status: status,
    );

    final token = await _getToken(customerId);
    if (token != null) {
      await _sendPush(
        fcmToken: token,
        title: title,
        body: body,
        data: {'orderId': orderId, 'type': 'order_status', 'status': status},
      );
    }
  }
}
