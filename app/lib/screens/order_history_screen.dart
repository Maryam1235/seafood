import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class OrderHistoryScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const OrderHistoryScreen({super.key, this.onOpenDrawer});

  static const _navy = Color(0xFF3730A3);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('order_history')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: uid)
            .where('status', isEqualTo: 'delivered')
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
                    Icons.history_outlined,
                    size: 90,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Hakuna historia ya maagizo'
                        : 'No order history yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.isSwahili
                        ? 'Maagizo yaliyowasilishwa yataonekana hapa'
                        : 'Delivered orders will appear here',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final order = doc.data() as Map<String, dynamic>;
              final items = (order['items'] as List?) ?? [];
              final total = order['total'] ?? 0;
              final grandTotal = order['grandTotal'] ?? total;
              final createdAt = order['createdAt'] as Timestamp?;
              final delivery = order['delivery'] as Map<String, dynamic>?;
              final deliveredAt = delivery?['deliveredAt'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with delivered badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.isSwahili
                                    ? 'Agizo #${doc.id.substring(0, 6).toUpperCase()}'
                                    : 'Order #${doc.id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (createdAt != null)
                                Text(
                                  lang.isSwahili
                                      ? 'Iliagizwa: '
                                      : 'Placed: '
                                            '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lang.isSwahili ? 'Imewasilishwa' : 'Delivered',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Items list
                    ...items
                        .take(2)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item['imageUrl'] != null
                                      ? Image.network(
                                          item['imageUrl'],
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                width: 48,
                                                height: 48,
                                                color: Colors.grey.shade100,
                                                child: Icon(
                                                  Icons.set_meal,
                                                  color: Colors.grey.shade300,
                                                  size: 24,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey.shade100,
                                          child: Icon(
                                            Icons.set_meal,
                                            color: Colors.grey.shade300,
                                            size: 24,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  'x${item['quantity']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (items.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${items.length - 2} ${lang.isSwahili ? 'bidhaa zaidi' : 'more items'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),

                    // Footer: delivery date + total
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (deliveredAt != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${lang.isSwahili ? 'Iliwasilishwa' : 'Delivered on'}: '
                                    '${deliveredAt.toDate().day}/${deliveredAt.toDate().month}/${deliveredAt.toDate().year}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lang.isSwahili ? 'Jumla' : 'Total',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'TShs ${grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _navy,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
