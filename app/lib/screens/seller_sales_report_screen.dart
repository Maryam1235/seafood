import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class SellerSalesReportScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const SellerSalesReportScreen({super.key, this.onOpenDrawer});

  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF3730A3);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // ── helpers ────────────────────────────────────────────────────────────────
  String _fmt(double n) {
    if (n >= 1000000) return 'TShs ${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return 'TShs ${(n / 1000).toStringAsFixed(1)}K';
    return 'TShs ${n.toStringAsFixed(0)}';
  }

  String _monthKey(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _last6Months() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      return {
        'key': '${d.year}-${d.month.toString().padLeft(2, '0')}',
        'label': _months[d.month - 1],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Ripoti ya Mauzo' : 'Sales Report'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter orders that contain this seller's items
          final allOrders = (snapshot.data?.docs ?? [])
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .where((o) {
            final items = (o['items'] as List?) ?? [];
            return items.any((i) => i['sellerId'] == uid);
          }).toList();

          final deliveredOrders =
              allOrders.where((o) => o['status'] == 'delivered').toList();

          // ── KPIs ────────────────────────────────────────────────────────
          double totalRevenue = 0;
          double totalItems = 0;
          final Map<String, double> productSales = {};

          for (final order in deliveredOrders) {
            final items = (order['items'] as List?) ?? [];
            final myItems = items.where((i) => i['sellerId'] == uid);
            for (final item in myItems) {
              final revenue =
                  ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble();
              totalRevenue += revenue;
              totalItems += (item['quantity'] ?? 1).toDouble();
              final name = item['name'] ?? 'Unknown';
              productSales[name] = (productSales[name] ?? 0) + revenue;
            }
          }

          final avgOrderValue = deliveredOrders.isEmpty
              ? 0.0
              : totalRevenue / deliveredOrders.length;

          final pendingCount =
              allOrders.where((o) => o['status'] == 'pending').length;
          final confirmedCount =
              allOrders.where((o) => o['status'] == 'confirmed').length;
          final cancelledCount =
              allOrders.where((o) => o['status'] == 'cancelled').length;

          // ── Monthly revenue ──────────────────────────────────────────────
          final months = _last6Months();
          final monthlyData = months.map((m) {
            final mo = deliveredOrders
                .where(
                  (o) => _monthKey(o['createdAt'] as Timestamp?) == m['key'],
                )
                .toList();
            double rev = 0;
            int count = 0;
            for (final order in mo) {
              final items = (order['items'] as List?) ?? [];
              final myItems = items.where((i) => i['sellerId'] == uid);
              for (final item in myItems) {
                rev +=
                    ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble();
              }
              count++;
            }
            return {'label': m['label'], 'revenue': rev, 'orders': count};
          }).toList();

          // ── Top products ─────────────────────────────────────────────────
          final topProducts = productSales.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final maxRevenue =
              topProducts.isEmpty ? 1.0 : topProducts.first.value;

          // ── Max monthly revenue for bar scale ────────────────────────────
          final maxMonthly = monthlyData
              .map((m) => (m['revenue'] as double))
              .fold(1.0, (a, b) => a > b ? a : b);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── KPI Cards ───────────────────────────────────────────────
                _sectionTitle(
                  lang.isSwahili ? 'Muhtasari' : 'Summary',
                ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _kpiCard(
                      lang.isSwahili ? 'Mapato Yote' : 'Total Revenue',
                      _fmt(totalRevenue),
                      Icons.attach_money,
                      Colors.green.shade700,
                      Colors.green.shade50,
                    ),
                    _kpiCard(
                      lang.isSwahili
                          ? 'Maagizo Yaliyokamilika'
                          : 'Completed Orders',
                      '${deliveredOrders.length}',
                      Icons.check_circle_outline,
                      _indigo,
                      Colors.indigo.shade50,
                    ),
                    _kpiCard(
                      lang.isSwahili ? 'Wastani wa Agizo' : 'Avg Order Value',
                      _fmt(avgOrderValue),
                      Icons.trending_up,
                      Colors.orange.shade700,
                      Colors.orange.shade50,
                    ),
                    _kpiCard(
                      lang.isSwahili ? 'Bidhaa Zilizouzwa' : 'Items Sold',
                      '${totalItems.toInt()}',
                      Icons.shopping_bag_outlined,
                      Colors.teal.shade700,
                      Colors.teal.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Order status breakdown ───────────────────────────────────
                _sectionTitle(
                  lang.isSwahili ? 'Hali ya Maagizo' : 'Order Status',
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _statusRow(
                        lang.isSwahili ? 'Yamekamilika' : 'Delivered',
                        deliveredOrders.length,
                        allOrders.length,
                        Colors.green.shade600,
                      ),
                      const SizedBox(height: 10),
                      _statusRow(
                        lang.isSwahili ? 'Yamethibitishwa' : 'Confirmed',
                        confirmedCount,
                        allOrders.length,
                        Colors.blue.shade600,
                      ),
                      const SizedBox(height: 10),
                      _statusRow(
                        lang.isSwahili ? 'Yanasubiri' : 'Pending',
                        pendingCount,
                        allOrders.length,
                        Colors.orange.shade600,
                      ),
                      const SizedBox(height: 10),
                      _statusRow(
                        lang.isSwahili ? 'Yameghairiwa' : 'Cancelled',
                        cancelledCount,
                        allOrders.length,
                        Colors.red.shade500,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Monthly revenue bar chart ───────────────────────────────
                _sectionTitle(
                  lang.isSwahili
                      ? 'Mapato ya Miezi 6 Iliyopita'
                      : 'Revenue — Last 6 Months',
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: monthlyData.map((m) {
                            final rev = (m['revenue'] as double);
                            final pct = rev / maxMonthly;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (rev > 0)
                                      Text(
                                        _fmt(rev).replaceAll('TShs ', ''),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: (pct * 120).clamp(4.0, 120.0),
                                      decoration: BoxDecoration(
                                        color: _indigo,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      m['label'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Top products ────────────────────────────────────────────
                _sectionTitle(
                  lang.isSwahili
                      ? 'Bidhaa Zinazoongoza kwa Mapato'
                      : 'Top Products by Revenue',
                ),
                topProducts.isEmpty
                    ? _emptyCard(
                        lang.isSwahili ? 'Hakuna mauzo bado' : 'No sales yet',
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Column(
                          children: topProducts.take(6).map((e) {
                            final pct = e.value / maxRevenue;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _fmt(e.value),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _indigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      );

  Widget _kpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Text(
          '(${(pct * 100).toStringAsFixed(0)}%)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _emptyCard(String message) => Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)],
      );
}
