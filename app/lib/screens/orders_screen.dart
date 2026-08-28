import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'map_screen.dart';
import 'delivery_selection_screen.dart';
import 'complaint_screen.dart';

class OrdersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const OrdersScreen({super.key, this.onOpenDrawer});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _navy = Color(0xFF3730A3);

  String _search = '';
  String _sortBy = 'newest'; // newest | oldest
  String _filterStatus =
      'all'; // all | pending | confirmed | delivered | cancelled
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

  String _statusLabel(String s, bool sw) {
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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.t('my_orders')),
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
          onPressed:
              widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // â”€â”€ Search bar + filter chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          final searchBar = Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText:
                        lang.isSwahili ? 'Tafuta agizo...' : 'Search orders...',
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
                // Sort + filter chips
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
                      // Status filters
                      for (final s in [
                        'all',
                        'pending',
                        'confirmed',
                        'delivered',
                        'cancelled',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: s == 'all'
                                ? (lang.isSwahili ? 'Zote' : 'All')
                                : _statusLabel(s, lang.isSwahili),
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
                searchBar,
                Expanded(
                  child: Center(
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
                          lang.isSwahili
                              ? 'Hakuna maagizo bado'
                              : 'No orders yet',
                          style: TextStyle(
                            fontSize: 18,
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

          // â”€â”€ Apply sort + filter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          var orders = snapshot.data!.docs.toList();

          // Sort client-side by createdAt (newest first by default)
          orders.sort((a, b) {
            final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          if (_sortBy == 'oldest') orders = orders.reversed.toList();

          // Status filter
          if (_filterStatus != 'all') {
            orders = orders.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return (d['status'] ?? 'pending') == _filterStatus;
            }).toList();
          }

          // Search by order ID or item name
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

          if (orders.isEmpty) {
            return Column(
              children: [
                searchBar,
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
              searchBar,
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final order = doc.data() as Map<String, dynamic>;
                    final items = (order['items'] as List?) ?? [];
                    final total = order['total'] ?? 0;
                    final grandTotal = order['grandTotal'] ?? total;
                    final status = order['status'] ?? 'pending';
                    final createdAt = order['createdAt'] as Timestamp?;
                    final fulfillment = order['fulfillment'] ?? 'delivery';

                    return GestureDetector(
                      onTap: () =>
                          _showOrderDetail(context, doc.id, order, lang),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: 0.04),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: fulfillment == 'pickup'
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.blue.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              fulfillment == 'pickup'
                                                  ? Icons.storefront_outlined
                                                  : Icons.delivery_dining,
                                              size: 11,
                                              color: fulfillment == 'pickup'
                                                  ? Colors.green.shade700
                                                  : Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              fulfillment == 'pickup'
                                                  ? (lang.isSwahili
                                                      ? 'Kuchukua'
                                                      : 'Pickup')
                                                  : (lang.isSwahili
                                                      ? 'Utoaji'
                                                      : 'Delivery'),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: fulfillment == 'pickup'
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(status, lang.isSwahili),
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
                            // Items preview
                            ...items.take(2).map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: item['imageUrl'] != null
                                              ? Image.network(
                                                  item['imageUrl'],
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _imgPlaceholder(),
                                                )
                                              : _imgPlaceholder(),
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
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  bottom: 4,
                                ),
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
                            // Total + tap hint
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
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.touch_app_outlined,
                                        size: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        lang.isSwahili
                                            ? 'Gusa kwa maelezo'
                                            : 'Tap for details',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'TShs ${(grandTotal as num).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  void _showOrderDetail(
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
          _OrderDetailSheet(orderId: orderId, order: order, lang: lang),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade100,
        child: Icon(Icons.set_meal, color: Colors.grey.shade300, size: 24),
      );
}

// â”€â”€ Sort chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    const navy = Color(0xFF3730A3);
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

// â”€â”€ Status filter chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
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

// â”€â”€ Order detail + payment sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _OrderDetailSheet extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> order;
  final LanguageProvider lang;

  const _OrderDetailSheet({
    required this.orderId,
    required this.order,
    required this.lang,
  });

  static const _navy = Color(0xFF3730A3);

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

  String _statusLabel(String s) {
    if (lang.isSwahili) {
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

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List?) ?? [];
    final total = (order['total'] ?? 0) as num;
    final grandTotal = (order['grandTotal'] ?? total) as num;
    final deliveryCost = grandTotal - total;
    final status = order['status'] ?? 'pending';
    final fulfillment = order['fulfillment'] ?? 'delivery';
    final createdAt = order['createdAt'] as Timestamp?;
    final delivery = order['delivery'] as Map<String, dynamic>?;

    // Collect unique seller IDs from items
    final sellerIds = items
        .map((i) => i['sellerId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${lang.isSwahili ? 'Agizo' : 'Order'} #${orderId.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  // â”€â”€ Items â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  _sectionTitle(lang.isSwahili ? 'Bidhaa' : 'Items'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      children: items.asMap().entries.map((e) {
                        final i = e.key;
                        final item = e.value as Map<String, dynamic>;
                        final subtotal =
                            (item['price'] ?? 0) * (item['quantity'] ?? 1);
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
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
                                            errorBuilder: (_, __, ___) =>
                                                _imgBox(),
                                          )
                                        : _imgBox(),
                                  ),
                                  const SizedBox(width: 12),
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
                                          'TShs ${(item['price'] ?? 0).toStringAsFixed(0)} / ${item['unit'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'x${item['quantity']}',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'TShs ${subtotal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (i < items.length - 1)
                              Divider(height: 1, color: Colors.grey.shade100),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // â”€â”€ Order summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  _sectionTitle(lang.isSwahili ? 'Muhtasari' : 'Summary'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      children: [
                        _summaryRow(
                          lang.isSwahili ? 'Jumla ya Bidhaa' : 'Items Subtotal',
                          'TShs ${total.toStringAsFixed(0)}',
                        ),
                        if (fulfillment == 'delivery' && deliveryCost > 0) ...[
                          const SizedBox(height: 8),
                          _summaryRow(
                            lang.isSwahili ? 'Ada ya Utoaji' : 'Delivery Fee',
                            'TShs ${deliveryCost.toStringAsFixed(0)}',
                          ),
                        ],
                        if (fulfillment == 'pickup') ...[
                          const SizedBox(height: 8),
                          _summaryRow(
                            lang.isSwahili ? 'Ada ya Utoaji' : 'Delivery Fee',
                            lang.isSwahili ? 'Bila ada' : 'Free',
                            valueColor: Colors.green.shade700,
                          ),
                        ],
                        const Divider(height: 20),
                        _summaryRow(
                          lang.isSwahili ? 'Jumla Yote' : 'Grand Total',
                          'TShs ${grandTotal.toStringAsFixed(0)}',
                          bold: true,
                        ),
                        const SizedBox(height: 10),
                        // Fulfillment type + map button for driver location
                        Row(
                          children: [
                            Icon(
                              fulfillment == 'pickup'
                                  ? Icons.storefront_outlined
                                  : Icons.delivery_dining,
                              size: 15,
                              color: fulfillment == 'pickup'
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                fulfillment == 'pickup'
                                    ? (lang.isSwahili
                                        ? 'Kuja Kuchukua â€” Bila ada ya utoaji'
                                        : 'Pick Up â€” No delivery fee')
                                    : (lang.isSwahili
                                        ? 'Utoaji â€” Dereva: ${delivery?['driverName'] ?? 'N/A'}'
                                        : 'Delivery â€” Driver: ${delivery?['driverName'] ?? 'N/A'}'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: fulfillment == 'pickup'
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Map button â€” shows driver's current location
                            if (fulfillment != 'pickup' &&
                                delivery?['driverId'] != null)
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(delivery!['driverId'] as String)
                                    .get(),
                                builder: (context, driverSnap) {
                                  final driverData = driverSnap.data?.data()
                                      as Map<String, dynamic>?;
                                  final loc = driverData?['location']
                                      as Map<String, dynamic>?;
                                  final lat =
                                      (loc?['latitude'] as num?)?.toDouble();
                                  final lng =
                                      (loc?['longitude'] as num?)?.toDouble();
                                  if (lat == null || lng == null) {
                                    return const SizedBox();
                                  }
                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MapScreen(
                                          latitude: lat,
                                          longitude: lng,
                                          label: driverData?['fullName'] ??
                                              driverData?['username'] ??
                                              (delivery['driverName'] ??
                                                  'Driver'),
                                          subtitle: 'Driver • Live Location',
                                          pinColor: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(20),
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
                                            lang.isSwahili ? 'Ramani' : 'Map',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // â”€â”€ Fulfillment choice (confirmed, not yet chosen) â”€â”€
                  if (status == 'confirmed' &&
                      order['fulfillment'] == null &&
                      (delivery == null || delivery['driverId'] == null)) ...[
                    const SizedBox(height: 4),
                    _sectionTitle(
                      lang.isSwahili ? 'Jinsi ya Kupokea?' : 'How to Receive?',
                    ),
                    // Delivery option
                    _FulfillmentOption(
                      icon: Icons.delivery_dining,
                      iconColor: const Color(0xFF3730A3),
                      title: lang.isSwahili ? 'Utoaji' : 'Delivery',
                      subtitle: lang.isSwahili
                          ? 'Chagua dereva â€” bei inakokotolewa kwa umbali'
                          : 'Choose a driver â€” cost based on distance',
                      badge: lang.isSwahili ? 'Ada ya ziada' : 'Extra fee',
                      badgeColor: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliverySelectionScreen(
                              orderId: orderId,
                              orderTotal: total.toDouble(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Pickup option
                    _FulfillmentOption(
                      icon: Icons.storefront_outlined,
                      iconColor: Colors.green.shade700,
                      title:
                          lang.isSwahili ? 'Kuja Kuchukua' : 'Pick Up Yourself',
                      subtitle: lang.isSwahili
                          ? 'Nenda mwenyewe kwa muuzaji kuchukua agizo lako'
                          : "Go to the seller's location to collect your order",
                      badge: lang.isSwahili ? 'Bila ada' : 'Free',
                      badgeColor: Colors.green,
                      onTap: () async {
                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .update({
                          'fulfillment': 'pickup',
                          'grandTotal': total,
                        });
                        // Pickup skips ClickPesa â€” still write purchase_history.
                        try {
                          await ApiService.post(
                            '/recommendations/record-purchase',
                            {'orderId': orderId},
                          );
                        } catch (e) {
                          debugPrint(
                            'record-purchase failed for pickup order $orderId: $e',
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // â”€â”€ Payment status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  _sectionTitle(
                    lang.isSwahili ? 'Hali ya Malipo' : 'Payment Status',
                  ),
                  _PaymentStatusCard(
                    paymentStatus: order['paymentStatus'] as String?,
                    fulfillment: fulfillment,
                    lang: lang,
                  ),
                  const SizedBox(height: 16),

                  // â”€â”€ Estimated delivery time â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (order['estimatedDeliveryAt'] != null) ...[
                    _sectionTitle(
                      lang.isSwahili
                          ? (fulfillment == 'pickup'
                              ? 'Wakati wa Kuchukua'
                              : 'Wakati wa Utoaji')
                          : (fulfillment == 'pickup'
                              ? 'Estimated Pickup Time'
                              : 'Estimated Delivery Time'),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.teal.shade700),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.isSwahili
                                    ? (fulfillment == 'pickup'
                                        ? 'Inatarajiwa Kuchukua'
                                        : 'Inatarajiwa Kufikia')
                                    : (fulfillment == 'pickup'
                                        ? 'Ready for Pickup'
                                        : 'Expected Arrival'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                              Text(
                                () {
                                  final dt = (order['estimatedDeliveryAt']
                                          as Timestamp)
                                      .toDate();
                                  return '${dt.day}/${dt.month}/${dt.year} '
                                      '${dt.hour.toString().padLeft(2, '0')}:'
                                      '${dt.minute.toString().padLeft(2, '0')}';
                                }(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // â”€â”€ Confirm Receipt â€” delivery + escrow â”€â”€â”€â”€â”€â”€â”€â”€
                  // ── Driver on the way — info banner ──────────────
                  if (fulfillment == 'delivery' &&
                      delivery != null &&
                      delivery['driverId'] != null &&
                      (delivery['status'] == 'picking_up' ||
                          delivery['status'] == 'on_the_way') &&
                      order['driverConfirmed'] != true) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.delivery_dining,
                              color: Colors.teal.shade700, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.isSwahili
                                  ? 'Dereva yuko njiani. Utapata taarifa atakapofika.'
                                  : 'Your driver is on the way.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Confirm Delivery (customer) ───────────────────────
                  if (fulfillment == 'delivery' &&
                      order['driverConfirmed'] == true &&
                      status != 'delivered') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text(lang.isSwahili
                                  ? 'Thibitisha Kupokea'
                                  : 'Confirm Delivery'),
                              content: Text(lang.isSwahili
                                  ? 'Je, umepokea bidhaa zako?'
                                  : 'Have you received your items?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(lang.isSwahili ? 'Hapana' : 'No'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(lang.isSwahili
                                      ? 'Ndiyo, Nimepokea'
                                      : 'Yes, Received'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !context.mounted) return;

                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .update({
                            'status': 'delivered',
                            'customerConfirmedReceipt': true,
                            'deliveredAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lang.isSwahili
                                    ? 'Asante! Agizo limekamilika.'
                                    : 'Thank you! Order marked as delivered.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          lang.isSwahili
                              ? 'Nimethibitisha Kupokea'
                              : 'I Received My Order',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // â”€â”€ Confirm Pickup Collection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (fulfillment == 'pickup' &&
                      (status == 'pending' || status == 'confirmed') &&
                      order['customerConfirmedReceipt'] != true) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text(lang.isSwahili
                                  ? 'Thibitisha Kuchukua'
                                  : 'Confirm Collection'),
                              content: Text(lang.isSwahili
                                  ? 'Je, umekwisha kuchukua bidhaa zako kutoka kwa muuzaji?'
                                  : 'Have you collected your items from the seller?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(lang.isSwahili ? 'Hapana' : 'No'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(lang.isSwahili
                                      ? 'Ndiyo, Nimechukua'
                                      : 'Yes, Collected'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !context.mounted) return;

                          // Mark delivered + paid — customer confirmed collection
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .update({
                            'status': 'delivered',
                            'paymentStatus': 'paid',
                            'customerConfirmedReceipt': true,
                            'deliveredAt': FieldValue.serverTimestamp(),
                          });

                          // Notify sellers
                          final oDoc = await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .get();
                          final oItems = (oDoc.data()?['items'] as List?) ?? [];
                          final sids = oItems
                              .map((i) => i['sellerId'] as String?)
                              .whereType<String>()
                              .toSet();
                          for (final sid in sids) {
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .add({
                              'userId': sid,
                              'type': 'order_collected',
                              'title': 'Order Collected ✅',
                              'body':
                                  'Customer has confirmed collection. Payment is being processed.',
                              'orderId': orderId,
                              'read': false,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lang.isSwahili
                                    ? 'Asante! Malipo yanashughulikiwa.'
                                    : 'Thank you! Payment is being processed.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          lang.isSwahili
                              ? "Nimethibitisha Kuchukua"
                              : "I've Collected My Order",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // â”€â”€ Cancel Order (pending only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (status == 'pending') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showCancelDialog(context, orderId, lang),
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        label: Text(
                          lang.isSwahili ? 'Ghairi Agizo' : 'Cancel Order',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // â”€â”€ File a Complaint â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (status == 'confirmed' || status == 'delivered') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ComplaintScreen(
                                prefilledOrderId: orderId,
                                prefilledSellerId: sellerIds.isNotEmpty
                                    ? sellerIds.first
                                    : null,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.report_problem_outlined,
                            color: Colors.orange.shade700, size: 18),
                        label: Text(
                          lang.isSwahili
                              ? 'Wasilisha Malalamiko'
                              : 'Report an Issue',
                          style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? const Color(0xFF111827) : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (bold ? _navy : const Color(0xFF111827)),
          ),
        ),
      ],
    );
  }

  Widget _imgBox() => Container(
        width: 52,
        height: 52,
        color: Colors.grey.shade100,
        child: Icon(Icons.set_meal, color: Colors.grey.shade300, size: 24),
      );

  // â”€â”€ Cancel order with reason picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _showCancelDialog(
    BuildContext context,
    String orderId,
    LanguageProvider lang,
  ) async {
    String selectedReason = 'Changed my mind';
    final reasons = [
      'Changed my mind',
      'Ordered by mistake',
      'Found a better price',
      'Taking too long',
      'Other',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            lang.isSwahili ? 'Ghairi Agizo' : 'Cancel Order',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.isSwahili
                    ? 'Tafadhali chagua sababu ya kughairi:'
                    : 'Please select a reason for cancellation:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (r) => GestureDetector(
                  onTap: () => setModalState(() => selectedReason = r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          selectedReason == r
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selectedReason == r
                              ? const Color(0xFF1E1B4B)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(r, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.isSwahili ? 'Rudi' : 'Go Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(lang.isSwahili ? 'Ghairi' : 'Cancel Order'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      await CartService().cancelOrder(orderId, selectedReason);
      if (context.mounted) {
        Navigator.pop(context); // loading
        Navigator.pop(context); // sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isSwahili
                ? 'Agizo limeghairiwa. Hisa imerudishwa.'
                : 'Order cancelled. Stock has been restored.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // loading
        final msg = e.toString().contains('only_pending')
            ? (lang.isSwahili
                ? 'Agizo linaloweza kughairiwa ni lile la kusubiri tu.'
                : 'Only pending orders can be cancelled.')
            : 'Error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// â”€â”€ Fulfillment option card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FulfillmentOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback? onTap;

  const _FulfillmentOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.4,
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
  }
}

// â”€â”€ Payment status card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PaymentStatusCard extends StatelessWidget {
  final String? paymentStatus;
  final String fulfillment;
  final LanguageProvider lang;

  const _PaymentStatusCard({
    required this.paymentStatus,
    required this.fulfillment,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final status = paymentStatus ??
        (fulfillment == 'pickup' ? 'cash_on_pickup' : 'unpaid');

    Color color;
    IconData icon;
    String label;
    String sublabel;

    switch (status) {
      case 'held_in_escrow':
        color = Colors.blue.shade700;
        icon = Icons.lock_outline;
        label = lang.isSwahili ? 'Imelipwa (Kwenye Amana)' : 'Paid (In Escrow)';
        sublabel = lang.isSwahili
            ? 'Malipo yatatolewa unapothibitisha kupokea'
            : 'Funds released when you confirm receipt';
        break;
      case 'released':
        color = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        label = lang.isSwahili ? 'Malipo Yametolewa' : 'Payment Released';
        sublabel = lang.isSwahili
            ? 'Muuzaji na dereva wamelipwa'
            : 'Seller and driver have been paid';
        break;
      case 'cash_on_pickup':
        color = Colors.teal.shade700;
        icon = Icons.storefront_outlined;
        label = lang.isSwahili ? 'Lipa Unapochukua' : 'Cash on Pickup';
        sublabel = lang.isSwahili
            ? 'Lipa muuzaji unapokwenda kuchukua'
            : 'Pay the seller when you collect your order';
        break;
      case 'pending':
        color = Colors.orange.shade700;
        icon = Icons.hourglass_empty;
        label = lang.isSwahili ? 'Inasubiri Malipo' : 'Awaiting Payment';
        sublabel = lang.isSwahili
            ? 'Kamilisha malipo kupitia ClickPesa'
            : 'Complete payment via ClickPesa';
        break;
      case 'failed':
        color = Colors.red.shade700;
        icon = Icons.error_outline;
        label = lang.isSwahili ? 'Malipo Yameshindwa' : 'Payment Failed';
        sublabel = lang.isSwahili
            ? 'Jaribu tena au wasiliana na msaada'
            : 'Please retry or contact support';
        break;
      default: // unpaid
        color = Colors.grey.shade600;
        icon = Icons.payment_outlined;
        label = lang.isSwahili ? 'Bado Hajalipwa' : 'Unpaid';
        sublabel = lang.isSwahili
            ? 'Malipo yatafanywa baada ya uthibitishaji'
            : 'Payment processed after order confirmation';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
