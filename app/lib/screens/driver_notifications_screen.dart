import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';

class DriverNotificationsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const DriverNotificationsScreen({super.key, this.onOpenDrawer});

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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final notif = doc.data() as Map<String, dynamic>;
              final isRead = notif['read'] == true;
              final isDelivery = notif['type'] == 'new_delivery';
              final createdAt = notif['createdAt'] as Timestamp?;

              return GestureDetector(
                onTap: () async {
                  // Mark as read
                  await doc.reference.update({'read': true});
                  // Show order details if delivery request
                  if (isDelivery && notif['orderId'] != null) {
                    _showOrderDetails(context, notif['orderId'], lang);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.shade200
                          : Colors.teal.shade200,
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
  ) async {
    if (orderId == null) return;
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'delivery.status': 'on_the_way',
      'delivery.acceptedAt': FieldValue.serverTimestamp(),
    });
    await notifRef.update({'read': true, 'accepted': true});

    // Notify customer
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    final customerId = orderDoc.data()?['customerId'];
    if (customerId != null) {
      await NotificationService.sendOrderStatusNotification(
        customerId: customerId,
        orderId: orderId,
        status: 'confirmed',
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isSwahili
                ? 'Umekubali utoaji! Nenda kwa mteja.'
                : 'Delivery accepted! Head to the customer.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      // Show order details bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ActiveDeliverySheet(orderId: orderId, lang: lang),
      );
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
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
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

class _ActiveDeliverySheet extends StatelessWidget {
  final String orderId;
  final LanguageProvider lang;
  const _ActiveDeliverySheet({required this.orderId, required this.lang});

  static const _teal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
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
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final order = snap.data!.data() as Map<String, dynamic>?;
            if (order == null) return const SizedBox();
            final items = (order['items'] as List?) ?? [];
            final delivery = order['delivery'] as Map<String, dynamic>?;
            final customer = order['customerId'];

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

                // Status banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining, color: _teal, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isSwahili
                                  ? 'Utoaji Unaoendelea'
                                  : 'Active Delivery',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _teal,
                              ),
                            ),
                            Text(
                              lang.isSwahili
                                  ? 'Nenda kwa mteja haraka'
                                  : 'Head to the customer now',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Customer info
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(customer)
                      .get(),
                  builder: (context, cSnap) {
                    final cData = cSnap.data?.data() as Map<String, dynamic>?;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isSwahili ? 'Mteja' : 'Customer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: _teal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cData?['fullName'] ??
                                    cData?['username'] ??
                                    'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: _teal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cData?['phone'] ?? 'N/A',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: _teal,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cData?['location']?['name'] ?? 'N/A',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Items
                Text(
                  lang.isSwahili ? 'Bidhaa' : 'Items',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.isSwahili ? 'Utoaji' : 'Delivery fee',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      'TShs ${delivery?['cost']?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.isSwahili ? 'Jumla Yote' : 'Grand Total',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'TShs ${order['grandTotal']?.toStringAsFixed(0) ?? order['total']?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Mark as delivered
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .update({
                            'status': 'delivered',
                            'delivery.status': 'delivered',
                            'delivery.deliveredAt':
                                FieldValue.serverTimestamp(),
                          });
                      // Notify customer
                      if (customer != null) {
                        await NotificationService.sendOrderStatusNotification(
                          customerId: customer,
                          orderId: orderId,
                          status: 'delivered',
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      lang.isSwahili
                          ? 'Imefika - Kamilisha'
                          : 'Mark as Delivered',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
