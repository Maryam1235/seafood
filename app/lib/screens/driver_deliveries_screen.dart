import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';
import 'map_screen.dart';

// ── Active Delivery Screen ────────────────────────────────────────────────────
class ActiveDeliveryScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const ActiveDeliveryScreen({super.key, this.onOpenDrawer});

  static const _teal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('active_delivery')),
        backgroundColor: Colors.teal.shade700,
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
            .where('delivery.driverId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter active deliveries client-side — avoids composite index.
          // Include delivery.status == 'delivered' so the card stays visible
          // with an "Awaiting customer confirmation" banner after the driver
          // marks the order as handed over. Once the customer confirms,
          // status becomes 'delivered' and the order drops out here and
          // appears in Delivery History instead.
          final allDocs = snapshot.data?.docs ?? [];
          final activeDocs = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final topStatus = d['status'] as String? ?? '';
            final deliveryStatus = d['delivery']?['status'] as String?;
            // Once top-level status is 'delivered' the customer has confirmed —
            // drop the card so it moves to Delivery History.
            if (topStatus == 'delivered') return false;
            return deliveryStatus == 'picking_up' ||
                deliveryStatus == 'on_the_way' ||
                deliveryStatus == 'delivered'; // awaiting customer confirm
          }).toList()
            ..sort((a, b) {
              final aTs = ((a.data() as Map<String, dynamic>)['createdAt']
                          as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              final bTs = ((b.data() as Map<String, dynamic>)['createdAt']
                          as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              return bTs.compareTo(aTs);
            });

          if (activeDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Hakuna utoaji unaoendelea'
                        : 'No active deliveries',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeDocs.length,
            itemBuilder: (context, index) {
              final doc = activeDocs[index];
              final order = doc.data() as Map<String, dynamic>;
              final items = (order['items'] as List?) ?? [];
              final delivery = order['delivery'] as Map<String, dynamic>?;
              final deliveryStatus = delivery?['status'] ?? 'picking_up';
              final isPickingUp = deliveryStatus == 'picking_up';
              final isAwaitingCustomer = deliveryStatus == 'delivered' &&
                  order['status'] != 'delivered';

              // Collect unique seller IDs from items
              final sellerIds = items
                  .map((i) => i['sellerId'] as String?)
                  .whereType<String>()
                  .toSet()
                  .toList();

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
                    // ── Step progress banner ──────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isPickingUp
                            ? Colors.orange.shade50
                            : isAwaitingCustomer
                                ? Colors.purple.shade50
                                : Colors.teal.shade50,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPickingUp
                                    ? Icons.storefront
                                    : isAwaitingCustomer
                                        ? Icons.hourglass_top
                                        : Icons.delivery_dining,
                                color: isPickingUp
                                    ? Colors.orange.shade700
                                    : isAwaitingCustomer
                                        ? Colors.purple.shade600
                                        : _teal,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPickingUp
                                          ? (lang.isSwahili
                                              ? 'Hatua 1: Chukua kwa Muuzaji'
                                              : 'Step 1: Pick Up from Seller')
                                          : isAwaitingCustomer
                                              ? (lang.isSwahili
                                                  ? 'Hatua 3: Inasubiri Mteja Kuthibitisha'
                                                  : 'Step 3: Awaiting Customer Confirmation')
                                              : (lang.isSwahili
                                                  ? 'Hatua 2: Peleka kwa Mteja'
                                                  : 'Step 2: Deliver to Customer'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isPickingUp
                                            ? Colors.orange.shade800
                                            : isAwaitingCustomer
                                                ? Colors.purple.shade700
                                                : _teal,
                                      ),
                                    ),
                                    Text(
                                      '${lang.isSwahili ? 'Agizo' : 'Order'} #${doc.id.substring(0, 6).toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isPickingUp
                                            ? Colors.orange.shade600
                                            : isAwaitingCustomer
                                                ? Colors.purple.shade400
                                                : Colors.teal.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Step indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isPickingUp
                                      ? Colors.orange.shade100
                                      : isAwaitingCustomer
                                          ? Colors.purple.shade100
                                          : Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isPickingUp
                                      ? '1 / 3'
                                      : isAwaitingCustomer
                                          ? '3 / 3'
                                          : '2 / 3',
                                  style: TextStyle(
                                    color: isPickingUp
                                        ? Colors.orange.shade800
                                        : isAwaitingCustomer
                                            ? Colors.purple.shade800
                                            : Colors.teal.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: isPickingUp ? 0.5 : 1.0,
                              backgroundColor: Colors.grey.shade200,
                              color:
                                  isPickingUp ? Colors.orange.shade400 : _teal,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Seller info (shown when picking up) ───────
                    if (isPickingUp)
                      ...sellerIds.map(
                        (sellerId) => FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(sellerId)
                              .get(),
                          builder: (context, snap) {
                            final seller =
                                snap.data?.data() as Map<String, dynamic>?;
                            if (seller == null) return const SizedBox();
                            final sellerName = seller['fullName'] ??
                                seller['username'] ??
                                'Seller';
                            final sellerPhone = seller['phone'] ?? 'N/A';
                            final sellerLocation =
                                seller['location']?['name'] ?? 'N/A';

                            return Container(
                              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        size: 14,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        lang.isSwahili
                                            ? 'Nenda kwa Muuzaji'
                                            : 'Go to Seller',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                      const Spacer(),
                                      // ── Map button (seller) ──
                                      Builder(
                                        builder: (ctx) {
                                          final loc =
                                              seller['location'] as Map?;
                                          final lat = loc == null
                                              ? null
                                              : (loc['latitude'] as num?)
                                                  ?.toDouble();
                                          final lng = loc == null
                                              ? null
                                              : (loc['longitude'] as num?)
                                                  ?.toDouble();
                                          if (lat == null || lng == null) {
                                            return const SizedBox();
                                          }
                                          return GestureDetector(
                                            onTap: () =>
                                                ActiveDeliveryScreen._openMaps(
                                              ctx,
                                              lat,
                                              lng,
                                              seller['fullName'] ?? 'Seller',
                                              subtitle: sellerLocation,
                                              pinColor: Colors.orange.shade700,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade700,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.map_outlined,
                                                    size: 13,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    lang.isSwahili
                                                        ? 'Ramani'
                                                        : 'Map',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _infoRow(
                                    Icons.person_outline,
                                    sellerName,
                                    Colors.orange.shade700,
                                  ),
                                  const SizedBox(height: 4),
                                  _infoRow(
                                    Icons.phone_outlined,
                                    sellerPhone,
                                    Colors.orange.shade700,
                                  ),
                                  const SizedBox(height: 4),
                                  _infoRow(
                                    Icons.location_on_outlined,
                                    sellerLocation,
                                    Colors.orange.shade700,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // ── Customer info (shown when on the way) ─────
                    if (!isPickingUp)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(order['customerId'])
                            .get(),
                        builder: (context, snap) {
                          final customer =
                              snap.data?.data() as Map<String, dynamic>?;
                          return Container(
                            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_pin_outlined,
                                      size: 14,
                                      color: Colors.teal.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.isSwahili
                                          ? 'Nenda kwa Mteja'
                                          : 'Go to Customer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade800,
                                      ),
                                    ),
                                    const Spacer(),
                                    // ── Map button (customer) ──
                                    Builder(
                                      builder: (ctx) {
                                        final loc =
                                            customer?['location'] as Map?;
                                        final lat = loc == null
                                            ? null
                                            : (loc['latitude'] as num?)
                                                ?.toDouble();
                                        final lng = loc == null
                                            ? null
                                            : (loc['longitude'] as num?)
                                                ?.toDouble();
                                        if (lat == null || lng == null) {
                                          return const SizedBox();
                                        }
                                        return GestureDetector(
                                          onTap: () =>
                                              ActiveDeliveryScreen._openMaps(
                                            ctx,
                                            lat,
                                            lng,
                                            customer?['fullName'] ?? 'Customer',
                                            subtitle: customer?['location']
                                                    ?['name'] ??
                                                '',
                                            pinColor: Colors.teal.shade700,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.map_outlined,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  lang.isSwahili
                                                      ? 'Ramani'
                                                      : 'Map',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.person_outline,
                                  customer?['fullName'] ??
                                      customer?['username'] ??
                                      'N/A',
                                  Colors.teal.shade700,
                                ),
                                const SizedBox(height: 4),
                                _infoRow(
                                  Icons.phone_outlined,
                                  customer?['phone'] ?? 'N/A',
                                  Colors.teal.shade700,
                                ),
                                const SizedBox(height: 4),
                                _infoRow(
                                  Icons.location_on_outlined,
                                  customer?['location']?['name'] ?? 'N/A',
                                  Colors.teal.shade700,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    // ── Items preview ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        children: items
                            .take(2)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: item['imageUrl'] != null
                                          ? Image.network(
                                              item['imageUrl'],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.grey.shade100,
                                              child: const Icon(
                                                Icons.set_meal,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'x${item['quantity']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    // ── Totals ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.isSwahili ? 'Jumla Yote' : 'Grand Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                'TShs ${order['grandTotal']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _teal,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                lang.isSwahili
                                    ? 'Ada ya Utoaji'
                                    : 'Your Delivery Fee',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                'TShs ${delivery?['cost']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Action button ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: isAwaitingCustomer
                          // Step 3: driver's job is done — show waiting state
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.purple.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.hourglass_top,
                                      color: Colors.purple.shade600, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    lang.isSwahili
                                        ? 'Inasubiri mteja kuthibitisha'
                                        : 'Waiting for customer to confirm',
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (isPickingUp) {
                                    // Step 1 complete → now heading to customer
                                    await FirebaseFirestore.instance
                                        .collection('orders')
                                        .doc(doc.id)
                                        .update({
                                      'delivery.status': 'on_the_way',
                                      'delivery.pickedUpAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            lang.isSwahili
                                                ? 'Umechukua bidhaa! Nenda kwa mteja.'
                                                : 'Items picked up! Head to the customer.',
                                          ),
                                          backgroundColor: _teal,
                                        ),
                                      );
                                    }
                                  } else {
                                    // Step 2 complete → driver has handed over.
                                    // Do NOT set status:'delivered' — the
                                    // customer must confirm receipt first.
                                    await FirebaseFirestore.instance
                                        .collection('orders')
                                        .doc(doc.id)
                                        .update({
                                      'driverConfirmed': true,
                                      'delivery.status': 'delivered',
                                      'delivery.deliveredAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            lang.isSwahili
                                                ? 'Imekamilika! Inasubiri mteja kuthibitisha.'
                                                : 'Handed over! Waiting for customer to confirm.',
                                          ),
                                          backgroundColor:
                                              Colors.purple.shade700,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(
                                  isPickingUp
                                      ? Icons.storefront_outlined
                                      : Icons.check_circle_outline,
                                ),
                                label: Text(
                                  isPickingUp
                                      ? (lang.isSwahili
                                          ? 'Nimechukua — Nenda kwa Mteja'
                                          : 'Picked Up — Head to Customer')
                                      : (lang.isSwahili
                                          ? 'Imefika — Mteja Athibitishe'
                                          : 'Delivered — Awaiting Customer'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPickingUp
                                      ? Colors.orange.shade700
                                      : _teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
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

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Opens the in-app map screen centred on [destLat]/[destLng].
  static void _openMaps(
    BuildContext context,
    double destLat,
    double destLng,
    String label, {
    String? subtitle,
    Color? pinColor,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          latitude: destLat,
          longitude: destLng,
          label: label,
          subtitle: subtitle,
          pinColor: pinColor,
        ),
      ),
    );
  }
}

// ── Delivery History Screen ───────────────────────────────────────────────────
class DeliveryHistoryScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const DeliveryHistoryScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('delivery_history')),
        backgroundColor: Colors.teal.shade700,
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
            .where('delivery.driverId', isEqualTo: uid)
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
                  Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Hakuna historia ya utoaji'
                        : 'No delivery history',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
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
              final delivery = order['delivery'] as Map<String, dynamic>?;
              final deliveredAt = delivery?['deliveredAt'] as Timestamp?;
              final items = (order['items'] as List?) ?? [];
              final customerConfirmed =
                  order['customerConfirmedReceipt'] as bool? ?? false;
              final deliveryCost =
                  (delivery?['cost'] as num?)?.toDouble() ?? 0.0;

              return GestureDetector(
                onTap: () => _showOrderDetail(context, doc.id, order, lang),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${lang.isSwahili ? 'Agizo' : 'Order'} #${doc.id.substring(0, 6).toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (customerConfirmed) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      lang.isSwahili
                                          ? 'Imethibitishwa'
                                          : 'Confirmed',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${items.length} ${lang.isSwahili ? 'bidhaa' : 'item${items.length == 1 ? '' : 's'}'}  •  TShs ${deliveryCost.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (deliveredAt != null)
                              Text(
                                '${deliveredAt.toDate().day}/${deliveredAt.toDate().month}/${deliveredAt.toDate().year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showOrderDetail(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
    LanguageProvider lang,
  ) {
    final items = (order['items'] as List?) ?? [];
    final delivery = order['delivery'] as Map<String, dynamic>?;
    final deliveredAt = delivery?['deliveredAt'] as Timestamp?;
    final sellerIds = items
        .map((i) => i['sellerId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lang.isSwahili ? 'Agizo' : 'Order'} #${orderId.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (deliveredAt != null)
                        Text(
                          '${lang.isSwahili ? 'Imetolewa' : 'Delivered'} ${deliveredAt.toDate().day}/${deliveredAt.toDate().month}/${deliveredAt.toDate().year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Customer info
              _DetailSection(
                title: lang.isSwahili ? 'Mteja' : 'Customer',
                icon: Icons.person_outline,
                color: Colors.teal.shade700,
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(order['customerId'])
                      .get(),
                  builder: (context, snap) {
                    final c = snap.data?.data() as Map<String, dynamic>?;
                    return Column(
                      children: [
                        _DetailRow(
                          Icons.person,
                          c?['fullName'] ?? c?['username'] ?? 'N/A',
                        ),
                        _DetailRow(Icons.phone, c?['phone'] ?? 'N/A'),
                        _DetailRow(
                          Icons.location_on,
                          c?['location']?['name'] ?? 'N/A',
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Seller(s) info
              ...sellerIds.map(
                (sellerId) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DetailSection(
                    title: lang.isSwahili ? 'Muuzaji' : 'Seller',
                    icon: Icons.storefront_outlined,
                    color: Colors.orange.shade700,
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(sellerId)
                          .get(),
                      builder: (context, snap) {
                        final s = snap.data?.data() as Map<String, dynamic>?;
                        return Column(
                          children: [
                            _DetailRow(
                              Icons.person,
                              s?['fullName'] ?? s?['username'] ?? 'N/A',
                            ),
                            _DetailRow(Icons.phone, s?['phone'] ?? 'N/A'),
                            _DetailRow(
                              Icons.location_on,
                              s?['location']?['name'] ?? 'N/A',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Items
              _DetailSection(
                title: lang.isSwahili ? 'Bidhaa' : 'Items',
                icon: Icons.set_meal_outlined,
                color: Colors.indigo.shade600,
                child: Column(
                  children: items
                      .map<Widget>(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: item['imageUrl'] != null
                                    ? Image.network(
                                        item['imageUrl'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey.shade100,
                                        child: const Icon(
                                          Icons.set_meal,
                                          size: 20,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                'x${item['quantity']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Available Orders Screen ───────────────────────────────────────────────────
class AvailableOrdersScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const AvailableOrdersScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('available_orders')),
        backgroundColor: Colors.teal.shade700,
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
            .where('status', isEqualTo: 'pending')
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
                    Icons.assignment_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Hakuna maagizo yanayosubiri'
                        : 'No available orders',
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
              final order = doc.data() as Map<String, dynamic>;
              final items = (order['items'] as List?) ?? [];
              final createdAt = order['createdAt'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${lang.isSwahili ? 'Agizo' : 'Order'} #${doc.id.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              lang.isSwahili ? 'Inasubiri' : 'Pending',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...items.take(2).map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.set_meal,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item['name']} x${item['quantity']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TShs ${order['total']?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00695C),
                              fontSize: 15,
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ── Action buttons ─────────────────────────
                      Row(
                        children: [
                          // View details
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showOrderDetails(
                                  context, doc.id, order, lang),
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 16),
                              label: Text(
                                lang.isSwahili ? 'Maelezo' : 'Details',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal.shade700,
                                side: BorderSide(color: Colors.teal.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Accept delivery
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _acceptOrder(context, doc.id, order, lang),
                              icon: const Icon(Icons.delivery_dining, size: 16),
                              label: Text(
                                lang.isSwahili
                                    ? 'Kubali Utoaji'
                                    : 'Accept Delivery',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Accept an available order ─────────────────────────────────────────────
  Future<void> _acceptOrder(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
    LanguageProvider lang,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.isSwahili ? 'Kubali Utoaji' : 'Accept Delivery'),
        content: Text(
          lang.isSwahili
              ? 'Je, unataka kubali utoaji huu?\nTa ya utoaji: TShs ${order['total']?.toStringAsFixed(0) ?? '0'}'
              : 'Do you want to accept this delivery?\nOrder total: TShs ${order['total']?.toStringAsFixed(0) ?? '0'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.isSwahili ? 'Hapana' : 'No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(lang.isSwahili ? 'Ndiyo, Kubali' : 'Yes, Accept'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      // Get driver info
      final driverDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final driverData = driverDoc.data() ?? {};

      // Assign driver and set delivery to picking_up.
      // Do NOT change order status here — that auto-confirms before customer pays.
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'delivery.driverId': uid,
        'delivery.driverName':
            driverData['fullName'] ?? driverData['username'] ?? 'Driver',
        'delivery.driverPhone': driverData['phone'] ?? '',
        'delivery.status': 'picking_up',
        'delivery.acceptedAt': FieldValue.serverTimestamp(),
        // 'status' left unchanged intentionally
      });

      // Notify customer: driver assigned — NOT "order confirmed"
      final customerId = order['customerId'] as String?;
      if (customerId != null) {
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
            backgroundColor: Colors.teal.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Order detail bottom sheet ─────────────────────────────────────────────
  void _showOrderDetails(
    BuildContext context,
    String orderId,
    Map<String, dynamic> order,
    LanguageProvider lang,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AvailableOrderSheet(orderId: orderId, order: order, lang: lang),
    );
  }
}

// ── Available order detail bottom sheet ──────────────────────────────────────
class _AvailableOrderSheet extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> order;
  final LanguageProvider lang;

  const _AvailableOrderSheet({
    required this.orderId,
    required this.order,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List?) ?? [];
    final total = (order['total'] ?? 0) as num;
    final createdAt = order['createdAt'] as Timestamp?;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${lang.isSwahili ? 'Agizo' : 'Order'} #${orderId.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Customer info
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(order['customerId'])
                        .get(),
                    builder: (context, snap) {
                      final c = snap.data?.data() as Map<String, dynamic>?;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isSwahili ? 'Mteja' : 'Customer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  c?['fullName'] ?? c?['username'] ?? 'N/A',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  c?['location']?['name'] ?? 'N/A',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Items
                  Text(
                    lang.isSwahili ? 'Bidhaa' : 'Items',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item['imageUrl'] != null
                                  ? Image.network(item['imageUrl'],
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _imgBox())
                                  : _imgBox(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${item['name']} × ${item['quantity']}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              'TShs ${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00695C)),
                            ),
                          ],
                        ),
                      )),

                  const Divider(height: 24),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isSwahili ? 'Jumla' : 'Order Total',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'TShs ${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF00695C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgBox() => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.set_meal, size: 22, color: Colors.grey.shade400),
      );
}
