import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class DeliveryPersonnelScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const DeliveryPersonnelScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('delivery_personnel')),
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
            .collection('users')
            .where('role', isEqualTo: 'driver')
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
                    Icons.delivery_dining_outlined,
                    size: 90,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Hakuna madereva wanaopatikana'
                        : 'No delivery personnel available',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final drivers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final doc = drivers[index];
              final driver = doc.data() as Map<String, dynamic>;
              final name = driver['fullName'] ?? driver['username'] ?? 'Driver';
              final phone = driver['phone'] ?? '';
              final isOnline = driver['isOnline'] == true;
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

              return _DriverCard(
                name: name,
                phone: phone,
                initial: initial,
                isOnline: isOnline,
                driverId: doc.id,
                lang: lang,
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String name;
  final String phone;
  final String initial;
  final bool isOnline;
  final String driverId;
  final LanguageProvider lang;

  const _DriverCard({
    required this.name,
    required this.phone,
    required this.initial,
    required this.isOnline,
    required this.driverId,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(
                    0xFF3730A3,
                  ).withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Driver info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone.isNotEmpty ? phone : '—',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Delivery stats
                  _DeliveryStats(driverId: driverId, lang: lang),
                ],
              ),
            ),

            // Online/Offline badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOnline
                    ? (lang.isSwahili ? 'Mtandaoni' : 'Online')
                    : (lang.isSwahili ? 'Nje' : 'Offline'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green.shade700 : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStats extends StatelessWidget {
  final String driverId;
  final LanguageProvider lang;

  const _DeliveryStats({required this.driverId, required this.lang});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('delivery.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'delivered')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 13,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              '$count ${lang.isSwahili
                  ? 'utoaji'
                  : count == 1
                  ? 'delivery'
                  : 'deliveries'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        );
      },
    );
  }
}
