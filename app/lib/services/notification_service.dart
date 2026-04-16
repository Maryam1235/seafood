import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Background message handler - must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  // Initialize FCM
  static Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Save FCM token to Firestore
    await saveFcmToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground message: ${message.notification?.title}');
    });
  }

  // Save FCM token to user's Firestore document
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

  // Send notification to a specific user via Firestore trigger
  // (We store the notification in Firestore, and use Cloud Functions or direct FCM)
  static Future<void> sendDeliveryNotification({
    required String driverId,
    required String orderId,
    required String customerName,
    required String orderTotal,
    required String vehicleType,
  }) async {
    // Store notification in Firestore for the driver
    await _db.collection('notifications').add({
      'userId': driverId,
      'type': 'new_delivery',
      'title': 'New Delivery Request 🚀',
      'body':
          'You have a new delivery order from $customerName. Total: TShs $orderTotal',
      'orderId': orderId,
      'vehicleType': vehicleType,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Send order status update to customer
  static Future<void> sendOrderStatusNotification({
    required String customerId,
    required String orderId,
    required String status,
  }) async {
    String title, body;
    switch (status) {
      case 'confirmed':
        title = 'Order Confirmed ✅';
        body = 'Your order has been confirmed and a driver is on the way!';
        break;
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
