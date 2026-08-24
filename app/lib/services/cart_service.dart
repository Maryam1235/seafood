import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'recommendation_event_service.dart';

/// Products whose stock falls to this many units (or fewer) after an order
/// trigger a low-stock alert notification to the seller AND a browse-screen
/// badge for customers.
const _lowStockThreshold = 5;

class CartService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _cart =>
      _db.collection('users').doc(_uid).collection('cart');

  // ── Add or increment item in cart — respects available stock ──────────────
  Future<void> addToCart(Map<String, dynamic> product) async {
    final productId = product['id'] as String;
    final ref = _cart.doc(productId);

    final productDoc = await _db.collection('products').doc(productId).get();
    final availableStock =
        ((productDoc.data()?['stock'] ?? 0) as num).toDouble();

    final cartSnap = await ref.get();
    final currentQtyInCart = cartSnap.exists
        ? ((cartSnap.data() as Map<String, dynamic>)['quantity'] ?? 0) as num
        : 0;

    if (currentQtyInCart >= availableStock) {
      throw Exception('out_of_stock');
    }

    if (cartSnap.exists) {
      await ref.update({'quantity': FieldValue.increment(1)});
    } else {
      await ref.set({
        'productId': productId,
        'name': product['name'],
        'price': product['price'],
        'unit': product['unit'],
        'imageUrl': product['imageUrl'],
        'sellerId': product['sellerId'],
        'quantity': 1,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Remove item ───────────────────────────────────────────────────────────
  Future<void> removeFromCart(String productId) async {
    await _cart.doc(productId).delete();
  }

  // ── Update quantity — respects available stock ────────────────────────────
  Future<void> updateQuantity(
    String productId,
    int quantity, {
    double? maxStock,
  }) async {
    if (quantity <= 0) {
      await removeFromCart(productId);
    } else {
      final safeQty =
          maxStock != null ? quantity.clamp(1, maxStock.toInt()) : quantity;
      await _cart.doc(productId).update({'quantity': safeQty});
    }
  }

  // ── Stream cart items ─────────────────────────────────────────────────────
  Stream<QuerySnapshot> cartStream() => _cart.snapshots();

  // ── Place order ───────────────────────────────────────────────────────────
  // Decrements stock, marks product unavailable if stock hits 0,
  // writes purchase_history for recommendations, and checks low-stock threshold.
  Future<String> placeOrder(
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final orderRef = _db.collection('orders').doc();
    final List<Map<String, dynamic>> lowStockProducts = [];

    await _db.runTransaction((transaction) async {
      lowStockProducts.clear();

      // 1. Read all product docs first
      final productRefs = <String, DocumentReference>{};
      final productSnaps = <String, DocumentSnapshot>{};

      for (final item in items) {
        final productId = item['productId'] ?? item['id'];
        if (productId != null && !productRefs.containsKey(productId)) {
          final ref = _db.collection('products').doc(productId as String);
          productRefs[productId] = ref;
          productSnaps[productId] = await transaction.get(ref);
        }
      }

      // 2. Create order
      transaction.set(orderRef, {
        'customerId': _uid,
        'items': items,
        'total': total,
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Decrement stock + collect low-stock products
      for (final item in items) {
        final productId = item['productId'] ?? item['id'];
        if (productId == null) continue;

        final snap = productSnaps[productId];
        if (snap == null || !snap.exists) continue;

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] ?? 0).toDouble();
        final orderedQty = (item['quantity'] ?? 1).toDouble();
        final newStock =
            (currentStock - orderedQty).clamp(0.0, double.infinity);

        transaction.update(productRefs[productId]!, {
          'stock': newStock,
          if (newStock <= 0) 'isAvailable': false,
        });

        if (newStock <= _lowStockThreshold) {
          final sellerId = data['sellerId'] as String?;
          debugPrint(
            '[LowStock] product=$productId name=${data['name']} '
            'currentStock=$currentStock newStock=$newStock sellerId=$sellerId',
          );
          if (sellerId != null) {
            lowStockProducts.add({
              'sellerId': sellerId,
              'productId': productId,
              'productName': data['name'] ?? 'Product',
              'remainingStock': newStock,
              'unit': data['unit'] ?? 'unit',
            });
          }
        }
      }

      // 4. Clear cart
      for (final item in items) {
        final cartDocId = item['id'] ?? item['productId'];
        if (cartDocId != null) {
          transaction.delete(_cart.doc(cartDocId as String));
        }
      }
    });

    // 5. Write purchase_history for each item (used by recommendations)
    for (final item in items) {
      final productId = item['productId'] ?? item['id'];
      if (productId == null) continue;
      try {
        await _db.collection('purchase_history').add({
          'userId': _uid,
          'productId': productId,
          'orderId': orderRef.id,
          'quantity': item['quantity'] ?? 1,
          'price': item['price'] ?? 0,
          'category': item['category'],
          'name': item['name'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Also log as recommendation event
        await RecommendationEventService.logPurchase(item);
      } catch (e) {
        debugPrint('[CartService] purchase_history write failed: $e');
      }
    }

    // 6. Low-stock alerts to sellers
    debugPrint('[LowStock] ${lowStockProducts.length} product(s) need alerts.');
    for (final p in lowStockProducts) {
      try {
        await NotificationService.sendLowStockNotification(
          sellerId: p['sellerId'] as String,
          productId: p['productId'] as String,
          productName: p['productName'] as String,
          remainingStock: p['remainingStock'] as double,
          unit: p['unit'] as String,
        );
        // Also notify the customer who just placed the order
        await NotificationService.sendCustomerLowStockAlert(
          customerId: _uid,
          productName: p['productName'] as String,
          remainingStock: p['remainingStock'] as double,
          unit: p['unit'] as String,
        );
        debugPrint(
          '[LowStock] ✅ Alert sent for "${p['productName']}" — '
          '${p['remainingStock']} ${p['unit']} remaining.',
        );
      } catch (e) {
        debugPrint('[LowStock] ❌ Alert failed for ${p['productName']}: $e');
      }
    }

    return orderRef.id;
  }

  // ── Cancel order (customer side — only while pending) ────────────────────
  // Restores product stock atomically and notifies the seller.
  Future<void> cancelOrder(String orderId, String reason) async {
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('Order not found');

      final order = orderSnap.data() as Map<String, dynamic>;
      if (order['status'] != 'pending') {
        throw Exception('only_pending_can_be_cancelled');
      }

      final items = (order['items'] as List?) ?? [];

      // Read product docs first (reads before writes in transaction)
      final productRefs = <String, DocumentReference>{};
      final productSnaps = <String, DocumentSnapshot>{};

      for (final item in items) {
        final productId = item['productId'] ?? item['id'];
        if (productId != null && !productRefs.containsKey(productId)) {
          final ref = _db.collection('products').doc(productId as String);
          productRefs[productId] = ref;
          productSnaps[productId] = await transaction.get(ref);
        }
      }

      // Cancel the order
      transaction.update(orderRef, {
        'status': 'cancelled',
        'cancelledBy': 'customer',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Restore stock for each item
      for (final item in items) {
        final productId = item['productId'] ?? item['id'];
        if (productId == null) continue;

        final snap = productSnaps[productId];
        if (snap == null || !snap.exists) continue;

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] ?? 0).toDouble();
        final orderedQty = (item['quantity'] ?? 1).toDouble();
        final restoredStock = currentStock + orderedQty;

        transaction.update(productRefs[productId]!, {
          'stock': restoredStock,
          // Re-enable product if it was hidden due to zero stock
          if (currentStock <= 0) 'isAvailable': true,
        });
      }
    });

    // Notify each seller that the order was cancelled
    final orderDoc = await orderRef.get();
    final order = orderDoc.data() as Map<String, dynamic>;
    final items = (order['items'] as List?) ?? [];

    final Map<String, bool> notifiedSellers = {};
    for (final item in items) {
      final sellerId = item['sellerId'] as String?;
      if (sellerId == null || notifiedSellers.containsKey(sellerId)) continue;
      notifiedSellers[sellerId] = true;

      try {
        await NotificationService.sendOrderCancelledBySeller(
          sellerId: sellerId,
          orderId: orderId,
          reason: reason,
          cancelledBy: 'customer',
        );
      } catch (e) {
        debugPrint('[CartService] cancel notification failed: $e');
      }
    }
  }

  // ── Notify all sellers after order is placed ─────────────────────────────
  Future<void> notifySellers({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    final customerDoc = await _db.collection('users').doc(_uid).get();
    final customerName = customerDoc.data()?['fullName'] ??
        customerDoc.data()?['username'] ??
        'A customer';

    final Map<String, List<Map<String, dynamic>>> bySeller = {};
    for (final item in items) {
      final sellerId = item['sellerId'] as String?;
      if (sellerId == null) continue;
      bySeller.putIfAbsent(sellerId, () => []).add(item);
    }

    for (final entry in bySeller.entries) {
      final sellerId = entry.key;
      final sellerItems = entry.value;
      final subtotal = sellerItems.fold<double>(
        0,
        (acc, i) => acc + ((i['price'] ?? 0) * (i['quantity'] ?? 1)),
      );

      await NotificationService.sendNewOrderNotification(
        sellerId: sellerId,
        orderId: orderId,
        customerName: customerName,
        itemCount: sellerItems.length,
        subtotal: subtotal,
      );
    }
  }
}
