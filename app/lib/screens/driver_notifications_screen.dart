import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class DriverNotificationsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final ValueChanged<int>? onNavigate;
  const DriverNotificationsScreen({
    super.key,
    this.onOpenDrawer,
    this.onNavigate,
  });

  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Arifa' : 'Notifications'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed:
              widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili ? 'Hakuna arifa' : 'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          // Sort newest first client-side — no composite index required
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
              final isRead = notif['read'] == true;
              final isDelivery = notif['type'] == 'new_delivery';
              final createdAt = notif['createdAt'] as Timestamp?;

              return GestureDetector(
                onTap: () async {
                  // Mark as read
                  await doc.reference.update({'read': true});

                  if (isDelivery && notif['orderId'] != null) {
                    // If already accepted → go straight to Active Delivery
                    if (notif['accepted'] == true) {
                      widget.onNavigate?.call(2);
                    } else {
                      // Not yet accepted → show order details preview
                      _showOrderDetails(context, notif['orderId'], lang);
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isRead ? Colors.grey.shade200 : Colors.teal.shade200,
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
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDelivery
                                ? Colors.teal.shade100
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDelivery
                                ? Icons.delivery_dining
                                : Icons.info_outline,
                            color: isDelivery
                                ? Colors.teal.shade700
                                : Colors.blue.shade700,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 14,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.teal,
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
                              if (createdAt != null)
                                Text(
                                  _formatTime(createdAt.toDate()),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              // Already accepted — show tap hint to go to active delivery
                              if (isDelivery && notif['accepted'] == true) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.teal.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_shipping_outlined,
                                        size: 14,
                                        color: Colors.teal.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        lang.isSwahili
                                            ? 'Bonyeza kwenda Utoaji Unaoendelea'
                                            : 'Tap to go to Active Delivery',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.teal.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 11,
                                        color: Colors.teal.shade700,
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Accept / Reject buttons for unactioned delivery requests
                              if (isDelivery &&
                                  notif['accepted'] != true &&
                                  notif['rejected'] != true &&
                                  !_dismissed.contains(doc.id)) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(
                                            () => _dismissed.add(doc.id),
                                          );
                                          _rejectDelivery(
                                            context,
                                            notif['orderId'],
                                            doc.reference,
                                            lang,
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Text(
                                          lang.isSwahili ? 'Kataa' : 'Reject',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(
                                            () => _dismissed.add(doc.id),
                                          );
                                          _acceptDelivery(
                                            context,
                                            notif['orderId'],
                                            doc.reference,
                                            lang,
                                            widget.onNavigate,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          lang.isSwahili ? 'Kubali' : 'Accept',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _acceptDelivery(
    BuildContext context,
    String? orderId,
    DocumentReference notifRef,
    LanguageProvider lang,
    ValueChanged<int>? onNavigate,
  ) async {
    if (orderId == null) return;

    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'delivery.status': 'picking_up',
      'delivery.acceptedAt': FieldValue.serverTimestamp(),
    });
    await notifRef.update({'read': true, 'accepted': true});

    // Notify customer that a driver has been assigned and is coming
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    final customerId = orderDoc.data()?['customerId'];
    if (customerId != null) {
      // Write an in-app notification — driver assigned, not "order confirmed"
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId,
        'type': 'driver_assigned',
        'title': 'Driver On the Way 🚗',
        'body':
            'A driver has accepted your delivery and is heading to pick up your order.',
        'orderId': orderId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isSwahili
                ? 'Umekubali utoaji! Nenda kwa muuzaji kuchukua.'
                : 'Delivery accepted! Go pick up from the seller.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      // Navigate directly to Active Delivery screen (index 2 in DriverDashboard)
      onNavigate?.call(2);
    }
  }

  Future<void> _rejectDelivery(
    BuildContext context,
    String? orderId,
    DocumentReference notifRef,
    LanguageProvider lang,
  ) async {
    if (orderId == null) return;
    await notifRef.update({'read': true, 'rejected': true});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isSwahili ? 'Umekataa utoaji' : 'Delivery rejected',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOrderDetails(
    BuildContext context,
    String orderId,
    LanguageProvider lang,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(orderId: orderId, lang: lang),
    );
  }
}

// ── Order details bottom sheet (shown when tapping a notification) ────────────
class _OrderDetailsSheet extends StatelessWidget {
  final String orderId;
  final LanguageProvider lang;
  const _OrderDetailsSheet({required this.orderId, required this.lang});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final order = snap.data!.data() as Map<String, dynamic>?;
            if (order == null) return const SizedBox();
            final items = (order['items'] as List?) ?? [];
            final delivery = order['delivery'] as Map<String, dynamic>?;

            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  lang.isSwahili ? 'Maelezo ya Agizo' : 'Order Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: item['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.set_meal),
                          ),
                    title: Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('TShs ${item['price']} / ${item['unit']}'),
                    trailing: Text(
                      'x${item['quantity']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    lang.isSwahili ? 'Jumla ya Utoaji' : 'Delivery Fee',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    'TShs ${delivery?['cost']?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    lang.isSwahili ? 'Jumla Yote' : 'Grand Total',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  trailing: Text(
                    'TShs ${order['grandTotal']?.toStringAsFixed(0) ?? order['total']?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
