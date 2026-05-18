import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class CartService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _cart =>
      _db.collection('users').doc(_uid).collection('cart');

  // Add or increment item in cart — respects available stock
  Future<void> addToCart(Map<String, dynamic> product) async {
    final productId = product['id'] as String;
    final ref = _cart.doc(productId);

    // Fetch current stock from the product doc
    final productDoc = await _db.collection('products').doc(productId).get();
    final availableStock = ((productDoc.data()?['stock'] ?? 0) as num)
        .toDouble();

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

  // Remove item
  Future<void> removeFromCart(String productId) async {
    await _cart.doc(productId).delete();
  }

  // Update quantity — respects available stock
  Future<void> updateQuantity(
    String productId,
    int quantity, {
    double? maxStock,
  }) async {
    if (quantity <= 0) {
      await removeFromCart(productId);
    } else {
      // If maxStock provided, clamp to it
      final safeQty = maxStock != null
          ? quantity.clamp(1, maxStock.toInt())
          : quantity;
      await _cart.doc(productId).update({'quantity': safeQty});
    }
  }

  // Stream cart items
  Stream<QuerySnapshot> cartStream() => _cart.snapshots();

  // Place order — decrements stock and marks product unavailable if stock hits 0
  Future<String> placeOrder(
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      // 1. Read all product docs first (transactions require all reads before writes)
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

      // 2. Write: create the order
      transaction.set(orderRef, {
        'customerId': _uid,
        'items': items,
        'total': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Write: decrement stock for each ordered item
      for (final item in items) {
        final productId = item['productId'] ?? item['id'];
        if (productId == null) continue;

        final snap = productSnaps[productId];
        if (snap == null || !snap.exists) continue;

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] ?? 0).toDouble();
        final orderedQty = (item['quantity'] ?? 1).toDouble();
        final newStock = (currentStock - orderedQty).clamp(
          0.0,
          double.infinity,
        );

        transaction.update(productRefs[productId]!, {
          'stock': newStock,
          // Auto-hide product from browse screen when stock is exhausted
          if (newStock <= 0) 'isAvailable': false,
        });
      }

      // 4. Write: clear cart items
      for (final item in items) {
        final cartDocId = item['id'] ?? item['productId'];
        if (cartDocId != null) {
          transaction.delete(_cart.doc(cartDocId as String));
        }
      }
    });

    return orderRef.id;
  }

  // Notify all sellers after order is placed
  Future<void> notifySellers({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    // Get customer name
    final customerDoc = await _db.collection('users').doc(_uid).get();
    final customerName =
        customerDoc.data()?['fullName'] ??
        customerDoc.data()?['username'] ??
        'A customer';

    // Group items by seller
    final Map<String, List<Map<String, dynamic>>> bySeller = {};
    for (final item in items) {
      final sellerId = item['sellerId'] as String?;
      if (sellerId == null) continue;
      bySeller.putIfAbsent(sellerId, () => []).add(item);
    }

    // Notify each seller
    for (final entry in bySeller.entries) {
      final sellerId = entry.key;
      final sellerItems = entry.value;
      final subtotal = sellerItems.fold<double>(
        0,
        (sum, i) => sum + ((i['price'] ?? 0) * (i['quantity'] ?? 1)),
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
