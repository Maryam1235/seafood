import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Logs lightweight product interactions for the hybrid recommender.
///
/// Types:
/// - [click] — user opens a product card
/// - [view] — product detail is shown (same open often logs click + view)
/// - [add_to_cart] — user adds the product to cart
///
/// Writes to Firestore `user_interactions`. Failures are ignored so UI
/// never blocks on analytics.
class RecommendationEventService {
  RecommendationEventService._();

  static final _db = FirebaseFirestore.instance;

  /// Avoid spamming identical events for the same product in a short window.
  static final Map<String, DateTime> _lastLogged = {};
  static const _dedupeWindow = Duration(seconds: 45);

  static Future<void> logClick(Map<String, dynamic> product) =>
      _log('click', product);

  static Future<void> logView(Map<String, dynamic> product) =>
      _log('view', product);

  static Future<void> logAddToCart(Map<String, dynamic> product) =>
      _log('add_to_cart', product);

  static Future<void> _log(String type, Map<String, dynamic> product) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final productId =
          (product['id'] ?? product['productId'])?.toString();
      if (productId == null || productId.isEmpty) return;

      final key = '$uid|$productId|$type';
      final now = DateTime.now();
      final prev = _lastLogged[key];
      if (prev != null && now.difference(prev) < _dedupeWindow) return;
      _lastLogged[key] = now;

      // Cap in-memory map size
      if (_lastLogged.length > 200) {
        _lastLogged.remove(_lastLogged.keys.first);
      }

      await _db.collection('user_interactions').add({
        'userId': uid,
        'productId': productId,
        'type': type,
        'category': product['category'],
        'name': product['name'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RecommendationEventService.$type failed: $e');
    }
  }
}
