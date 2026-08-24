import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ── Android notification channels — must match MainActivity.kt ───────────────
const _ordersChannelId = 'zanseafood_orders';
const _stockChannelId = 'zanseafood_stock';

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background push: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;
  static int _localId = 0;

  // ── Init ─────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      await _initLocal();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('[FCM] Foreground: ${msg.notification?.title}');
        _showLocal(msg);
      });

      await saveFcmToken();
      _messaging.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessageOpenedApp.listen(
        (msg) => debugPrint('[FCM] Tapped (bg): ${msg.data}'),
      );

      final init = await _messaging.getInitialMessage();
      if (init != null)
        debugPrint('[FCM] Opened from terminated: ${init.data}');
    } catch (e) {
      debugPrint('[NotificationService] init error (non-fatal): $e');
    }
  }

  static Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final type = message.data['type'] ?? '';
    final channelId = type == 'low_stock' || type == 'product_low_stock'
        ? _stockChannelId
        : _ordersChannelId;
    final channelName =
        channelId == _stockChannelId ? 'Stock Alerts' : 'Order Notifications';

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        notif.body ?? '',
        contentTitle: notif.title,
      ),
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotif.show(
      _localId++,
      notif.title,
      notif.body,
      NotificationDetails(android: android, iOS: ios),
      payload: type,
    );
  }

  // ── FCM token ────────────────────────────────────────────────────────────
  static Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
      debugPrint('[FCM] Token saved for $uid');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (e) {
      debugPrint('[FCM] Save token failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Firestore in-app notification writers
  // Cloud Functions send the real FCM push; these write the in-app bell doc
  // so the badge refreshes immediately without waiting for a push round-trip.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> sendNewOrderNotification({
    required String sellerId,
    required String orderId,
    required String customerName,
    required int itemCount,
    required double subtotal,
  }) async {
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

  /// Low-stock alert → seller (written by CartService after order transaction).
  /// Cloud Function `onLowStockNotification` picks this up and sends FCM push.
  static Future<void> sendLowStockNotification({
    required String sellerId,
    required String productId,
    required String productName,
    required double remainingStock,
    required String unit,
  }) async {
    final isOut = remainingStock <= 0;
    await _db.collection('notifications').add({
      'userId': sellerId,
      'type': 'low_stock',
      'title': isOut ? 'Out of Stock ⚠️' : 'Low Stock Alert ⚠️',
      'body': isOut
          ? '"$productName" is out of stock. Restock to keep selling.'
          : '"$productName" has only ${remainingStock.toStringAsFixed(remainingStock.truncateToDouble() == remainingStock ? 0 : 1)} $unit left. Consider restocking soon.',
      'productId': productId,
      'productName': productName,
      'remainingStock': remainingStock,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notifies the customer who just ordered that the product is almost gone.
  static Future<void> sendCustomerLowStockAlert({
    required String customerId,
    required String productName,
    required double remainingStock,
    required String unit,
  }) async {
    if (remainingStock <= 0) return;
    await _db.collection('notifications').add({
      'userId': customerId,
      'type': 'product_low_stock',
      'title': 'Almost Sold Out! 🔥',
      'body': 'You got the last stock! "$productName" only has '
          '${remainingStock.toStringAsFixed(0)} $unit left now.',
      'productName': productName,
      'remainingStock': remainingStock,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notifies seller that a customer cancelled an order.
  static Future<void> sendOrderCancelledBySeller({
    required String sellerId,
    required String orderId,
    required String reason,
    required String cancelledBy,
  }) async {
    await _db.collection('notifications').add({
      'userId': sellerId,
      'type': 'order_cancelled',
      'title': 'Order Cancelled ❌',
      'body':
          'A customer cancelled order #${orderId.substring(0, 6).toUpperCase()}. '
              'Reason: $reason. Stock has been restored automatically.',
      'orderId': orderId,
      'reason': reason,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notifies seller of a new complaint.
  static Future<void> sendNewComplaintNotification({
    required String sellerId,
    required String complaintId,
    required String orderId,
    required String category,
  }) async {
    await _db.collection('notifications').add({
      'userId': sellerId,
      'type': 'new_complaint',
      'title': 'New Complaint Filed 🚨',
      'body': 'A customer filed a "$category" complaint on order '
          '#${orderId.substring(0, 6).toUpperCase()}. Please review and respond.',
      'complaintId': complaintId,
      'orderId': orderId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notifies customer that their complaint got a response.
  static Future<void> sendComplaintResponseNotification({
    required String customerId,
    required String complaintId,
    required String sellerName,
  }) async {
    await _db.collection('notifications').add({
      'userId': customerId,
      'type': 'complaint_response',
      'title': 'Complaint Response 💬',
      'body': '$sellerName has responded to your complaint.',
      'complaintId': complaintId,
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
