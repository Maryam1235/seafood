import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'complaint_screen.dart';

class CustomerComplaintsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const CustomerComplaintsScreen({super.key, this.onOpenDrawer});

  static const _navy = Color(0xFF3730A3);

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return Colors.orange;
      case 'responded':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Malalamiko Yangu' : 'My Complaints'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ComplaintScreen()),
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(lang.isSwahili ? 'Lalamiko Jipya' : 'New Complaint'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('customerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          // Sort newest first client-side
          final sorted = [...docs];
          sorted.sort((a, b) {
            final aTs = ((a.data() as Map)['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            final bTs = ((b.data() as Map)['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            return bTs.compareTo(aTs);
          });

          if (sorted.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sentiment_satisfied_alt,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Huna malalamiko. Karibu!'
                        : 'No complaints yet. All good!',
                    style: TextStyle(fontSize: 17, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.isSwahili
                        ? 'Gonga + kuwasilisha lalamiko'
                        : 'Tap + to file a complaint',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final doc = sorted[i];
              final complaint = doc.data() as Map<String, dynamic>;
              final category = complaint['category'] ?? '';
              final desc = complaint['description'] ?? '';
              final cStatus = complaint['status'] as String? ?? 'open';
              final createdAt = complaint['createdAt'] as Timestamp?;
              final orderId = complaint['orderId'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _statusColor(cStatus).withValues(alpha: 0.07),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (orderId.isNotEmpty)
                                Text(
                                  'Order #${orderId.substring(0, 6).toUpperCase()}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  _statusColor(cStatus).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cStatus[0].toUpperCase() + cStatus.substring(1),
                              style: TextStyle(
                                color: _statusColor(cStatus),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${createdAt.toDate().day}/'
                              '${createdAt.toDate().month}/'
                              '${createdAt.toDate().year}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],

                          // Seller response
                          if (complaint['response'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.store_outlined,
                                          size: 14,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 6),
                                      Text(
                                        lang.isSwahili
                                            ? 'Jibu la Muuzaji'
                                            : 'Seller Response',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    complaint['response'],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
