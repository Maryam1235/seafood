import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _cart =>
      _db.collection('users').doc(_uid).collection('cart');

  // Add or increment item in cart
  Future<void> addToCart(Map<String, dynamic> product) async {
    final ref = _cart.doc(product['id']);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({'quantity': FieldValue.increment(1)});
    } else {
      await ref.set({
        'productId': product['id'],
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

  // Update quantity
  Future<void> updateQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(productId);
    } else {
      await _cart.doc(productId).update({'quantity': quantity});
    }
  }

  // Stream cart items
  Stream<QuerySnapshot> cartStream() => _cart.orderBy('addedAt').snapshots();

  // Place order
  Future<void> placeOrder(
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final batch = _db.batch();
    final orderRef = _db.collection('orders').doc();

    batch.set(orderRef, {
      'customerId': _uid,
      'items': items,
      'total': total,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Clear cart
    for (final item in items) {
      batch.delete(_cart.doc(item['productId']));
    }

    await batch.commit();
  }
}
