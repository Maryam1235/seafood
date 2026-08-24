import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'edit_product_screen.dart';

class SellerNotificationsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const SellerNotificationsScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Arifa' : 'Notifications'),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        actions: [
          // Mark all as read
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final hasUnread = (snap.data?.docs.isNotEmpty) ?? false;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllRead(uid),
                child: Text(
                  lang.isSwahili ? 'Soma Zote' : 'Mark all read',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState(lang);
          }

          // Sort newest first client-side
          final docs = [...snapshot.data!.docs];
          docs.sort((a, b) {
            final aTs =
                ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
            final bTs =
                ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
            return bTs.compareTo(aTs);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final notif = doc.data() as Map<String, dynamic>;
              return _NotifCard(
                doc: doc,
                notif: notif,
                lang: lang,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Widget _emptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            lang.isSwahili ? 'Hakuna arifa' : 'No notifications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            lang.isSwahili
                ? 'Arifa za bidhaa na maagizo zitaonekana hapa'
                : 'Order and stock alerts will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Single notification card ──────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> notif;
  final LanguageProvider lang;

  const _NotifCard({
    required this.doc,
    required this.notif,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final type = notif['type'] as String? ?? '';
    final isRead = notif['read'] == true;
    final createdAt = notif['createdAt'] as Timestamp?;

    final config = _typeConfig(type);

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : config.bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? Colors.grey.shade200 : config.borderColor,
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: config.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(config.icon, color: config.iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif['title'] ?? '',
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: config.iconColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif['body'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (createdAt != null)
                          Text(
                            _formatTime(createdAt.toDate()),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        // Deep-link chip for low_stock — tap goes to edit product
                        if (type == 'low_stock' &&
                            notif['productId'] != null) ...[
                          GestureDetector(
                            onTap: () => _openEditProduct(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_box_outlined,
                                      size: 13, color: Colors.orange.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    lang.isSwahili ? 'Ongeza Hisa' : 'Restock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) async {
    // Mark as read
    await doc.reference.update({'read': true});
  }

  Future<void> _openEditProduct(BuildContext context) async {
    final productId = notif['productId'] as String?;
    if (productId == null) return;

    // Mark as read
    await doc.reference.update({'read': true});

    // Fetch the product doc and open edit screen
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .get();
    if (!snap.exists || !context.mounted) return;

    final product = {'id': snap.id, ...snap.data()!};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductScreen(product: product),
      ),
    );
  }

  _TypeConfig _typeConfig(String type) {
    switch (type) {
      case 'low_stock':
        return _TypeConfig(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange.shade700,
          iconBg: Colors.orange.shade100,
          bgColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade200,
        );
      case 'new_order':
        return _TypeConfig(
          icon: Icons.shopping_bag_outlined,
          iconColor: const Color(0xFF1E1B4B),
          iconBg: const Color(0xFFE8E7F8),
          bgColor: const Color(0xFFF0F0FB),
          borderColor: const Color(0xFFB8B7D8),
        );
      case 'order_status':
        return _TypeConfig(
          icon: Icons.receipt_long_outlined,
          iconColor: Colors.teal.shade700,
          iconBg: Colors.teal.shade50,
          bgColor: Colors.teal.shade50,
          borderColor: Colors.teal.shade200,
        );
      default:
        return _TypeConfig(
          icon: Icons.info_outline,
          iconColor: Colors.blue.shade700,
          iconBg: Colors.blue.shade50,
          bgColor: Colors.blue.shade50,
          borderColor: Colors.blue.shade200,
        );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _TypeConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color bgColor;
  final Color borderColor;
  const _TypeConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.bgColor,
    required this.borderColor,
  });
}
