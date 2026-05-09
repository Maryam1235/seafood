import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class SellerOrdersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const SellerOrdersScreen({super.key, this.onOpenDrawer});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const _navy = Color(0xFF1E1B4B);

  String _search = '';
  String _sortBy = 'newest';
  String _filterStatus = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String s, bool sw) {
    if (sw) {
      switch (s) {
        case 'pending':
          return 'Inasubiri';
        case 'confirmed':
          return 'Imethibitishwa';
        case 'delivered':
          return 'Imewasilishwa';
        case 'cancelled':
          return 'Imeghairiwa';
        default:
          return s;
      }
    }
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final sellerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('orders')),
        backgroundColor: _navy,
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
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // -- Search + filter bar ----------------------------------
          Widget filterBar = Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: lang.isSwahili
                        ? 'Tafuta agizo...'
                        : 'Search orders...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SortChip(
                        icon: Icons.arrow_downward,
                        label: lang.isSwahili ? 'Mpya Zaidi' : 'Newest',
                        selected: _sortBy == 'newest',
                        onTap: () => setState(() => _sortBy = 'newest'),
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        icon: Icons.arrow_upward,
                        label: lang.isSwahili ? 'Kongwe Zaidi' : 'Oldest',
                        selected: _sortBy == 'oldest',
                        onTap: () => setState(() => _sortBy = 'oldest'),
                      ),
                      const SizedBox(width: 16),
                      for (final s in [
                        'all',
                        'pending',
                        'confirmed',
                        'delivered',
                        'cancelled',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _StatusChip(
                            label: s == 'all'
                                ? (lang.isSwahili ? 'Zote' : 'All')
                                : _statusText(s, lang.isSwahili),
                            color: s == 'all' ? _navy : _statusColor(s),
                            selected: _filterStatus == s,
                            onTap: () => setState(() => _filterStatus = s),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Column(
              children: [
                filterBar,
                Expanded(child: _emptyState(lang)),
              ],
            );
          }

          // Filter by seller
          var orders = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final items = (data['items'] as List?) ?? [];
            return items.any((i) => i['sellerId'] == sellerId);
          }).toList();

          // Status filter
          if (_filterStatus != 'all') {
            orders = orders.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return (d['status'] ?? 'pending') == _filterStatus;
            }).toList();
          }

          // Search
          if (_search.isNotEmpty) {
            orders = orders.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final idMatch = doc.id.toLowerCase().contains(_search);
              final items = (d['items'] as List?) ?? [];
              final itemMatch = items.any(
                (i) => (i['name'] ?? '').toString().toLowerCase().contains(
                  _search,
                ),
              );
              return idMatch || itemMatch;
            }).toList();
          }

          if (_sortBy == 'oldest') orders = orders.reversed.toList();

          if (orders.isEmpty) {
            return Column(
              children: [
                filterBar,
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 70,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lang.isSwahili
                              ? 'Hakuna maagizo yanayolingana'
                              : 'No matching orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final order = doc.data() as Map<String, dynamic>;
                    final allItems = (order['items'] as List?) ?? [];
                    final myItems = allItems
                        .where((i) => i['sellerId'] == sellerId)
                        .toList();
                    final status = order['status'] ?? 'pending';
                    final createdAt = order['createdAt'] as Timestamp?;
                    final fulfillment = order['fulfillment'] ?? 'delivery';
                    final isPickup = fulfillment == 'pickup';
                    final subtotal = myItems.fold<double>(
                      0,
                      (acc, i) =>
                          acc + ((i['price'] ?? 0) * (i['quantity'] ?? 1)),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        // Highlight pickup orders with a green border
                        border: isPickup
                            ? Border.all(
                                color: Colors.green.withValues(alpha: 0.4),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          // -- Header ------------------------------
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isPickup
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : _navy.withValues(alpha: 0.04),
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
                                      '${lang.isSwahili ? 'Agizo' : 'Order'} #${doc.id.substring(0, 6).toUpperCase()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                                Row(
                                  children: [
                                    // Fulfillment badge
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isPickup
                                            ? Colors.green.withValues(
                                                alpha: 0.12,
                                              )
                                            : Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPickup
                                                ? Icons.storefront_outlined
                                                : Icons.delivery_dining,
                                            size: 12,
                                            color: isPickup
                                                ? Colors.green.shade700
                                                : Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isPickup
                                                ? (lang.isSwahili
                                                      ? 'Kuchukua'
                                                      : 'Pickup')
                                                : (lang.isSwahili
                                                      ? 'Utoaji'
                                                      : 'Delivery'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isPickup
                                                  ? Colors.green.shade700
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          status,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusText(status, lang.isSwahili),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // -- Pickup info banner -------------------
                          if (isPickup)
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(order['customerId'])
                                  .get(),
                              builder: (context, snap) {
                                final customer =
                                    snap.data?.data() as Map<String, dynamic>?;
                                final customerName =
                                    customer?['fullName'] ??
                                    customer?['username'] ??
                                    '';
                                final customerPhone = customer?['phone'] ?? '';
                                final customerLocation =
                                    customer?['location']?['name'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    0,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.storefront,
                                            size: 15,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            lang.isSwahili
                                                ? 'Mteja atakuja kuchukua'
                                                : 'Customer will pick up',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (customerName.isNotEmpty)
                                        _infoRow(
                                          Icons.person_outline,
                                          customerName,
                                          Colors.green.shade700,
                                        ),
                                      if (customerPhone.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _infoRow(
                                          Icons.phone_outlined,
                                          customerPhone,
                                          Colors.green.shade700,
                                        ),
                                      ],
                                      if (customerLocation.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _infoRow(
                                          Icons.location_on_outlined,
                                          customerLocation,
                                          Colors.green.shade700,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            // -- Delivery: customer info row ------
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(order['customerId'])
                                  .get(),
                              builder: (context, snap) {
                                final customer =
                                    snap.data?.data() as Map<String, dynamic>?;
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        customer?['fullName'] ??
                                            customer?['username'] ??
                                            (lang.isSwahili
                                                ? 'Mteja'
                                                : 'Customer'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer?['phone'] ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                          // -- Items --------------------------------
                          ...myItems.map(
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
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 52,
                                            height: 52,
                                            color: Colors.grey.shade100,
                                            child: Icon(
                                              Icons.set_meal,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'TShs ${item['price']?.toStringAsFixed(0)} / ${item['unit']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'x${item['quantity']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // -- Subtotal + action buttons -------------
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      lang.isSwahili ? 'Jumla' : 'Subtotal',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      'TShs ${subtotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _navy,
                                      ),
                                    ),
                                  ],
                                ),

                                // Pending: Reject / Confirm
                                if (status == 'pending') ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateStatus(
                                            doc.id,
                                            'cancelled',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(
                                              color: Colors.red,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            lang.isSwahili ? 'Kataa' : 'Reject',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _updateStatus(
                                            doc.id,
                                            'confirmed',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _navy,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            lang.isSwahili
                                                ? 'Thibitisha'
                                                : 'Confirm',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // REPLACE_BLOCK
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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

  Widget _emptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 90,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            lang.isSwahili ? 'Hakuna maagizo bado' : 'No orders yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// -- Sort chip --------------------------------------------------------------
class _SortChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1E1B4B);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? navy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? navy : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Status chip ------------------------------------------------------------
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
