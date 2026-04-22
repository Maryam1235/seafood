import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

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
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Search bar + filter chips ──────────────────────────
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

          // ── Apply sort + filter ────────────────────────────────
          var orders = snapshot.data!.docs.toList();

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

          // Sort (Firestore already returns newest-first; reverse for oldest)
          if (_sortBy == 'oldest') {
            orders = orders.reversed.toList();
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
                    final status = order['status'] ?? 'pending';
                    final createdAt = order['createdAt'] as Timestamp?;

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
                          ),
                          // Items preview
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
                          // Total
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
                                  'TShs ${total.toStringAsFixed(0)}',
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

  Widget _imgPlaceholder() => Container(
    width: 48,
    height: 48,
    color: Colors.grey.shade100,
    child: Icon(Icons.set_meal, color: Colors.grey.shade300, size: 24),
  );
}

// ── Sort chip ──────────────────────────────────────────────────────────────
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

// ── Status filter chip ─────────────────────────────────────────────────────
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
