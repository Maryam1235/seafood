import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';

class SellerOrdersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const SellerOrdersScreen({super.key, this.onOpenDrawer});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF1E1B4B);

  late TabController _tabController;
  late final Stream<QuerySnapshot> _allOrdersStream;

  // Tab definitions: label (en), label (sw), status filter
  static const _tabs = [
    ('New Orders', 'Maagizo Mapya', 'pending'),
    ('Confirmed', 'Yamethibitishwa', 'confirmed'),
    ('Processing', 'Yanashughulikiwa', 'on_the_way'),
    ('Completed', 'Yamekamilika', 'delivered'),
    ('Cancelled', 'Yameghairiwa', 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Cache the stream so it is not recreated on every build()
    _allOrdersStream =
        FirebaseFirestore.instance.collection('orders').snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'on_the_way':
        return Colors.purple;
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
        case 'on_the_way':
          return 'Inafika';
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
        return 'New';
      case 'confirmed':
        return 'Confirmed';
      case 'on_the_way':
        return 'Processing';
      case 'delivered':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  Future<void> _updateStatus(
    String orderId,
    String newStatus,
    String customerId, {
    int? prepMinutes,
  }) async {
    final Map<String, dynamic> update = {'status': newStatus};

    // When confirming a pickup order, set estimated ready time.
    // For delivery orders the seller will set the delivery time separately
    // once fulfillment is chosen and a driver is assigned.
    if (newStatus == 'confirmed' && prepMinutes != null) {
      final now = DateTime.now();
      final readyAt = now.add(Duration(minutes: prepMinutes));
      update['estimatedReadyAt'] = Timestamp.fromDate(readyAt);
      // Clear any stale estimatedDeliveryAt so the delivery-time button shows.
      update['estimatedDeliveryAt'] = null;
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(update);

    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    final sellerName = sellerDoc.data()?['fullName'] ??
        sellerDoc.data()?['username'] ??
        'Seller';

    await NotificationService.sendOrderConfirmationNotification(
      customerId: customerId,
      orderId: orderId,
      confirmed: newStatus == 'confirmed',
      sellerName: sellerName,
    );
  }

  /// Writes the seller-confirmed estimated delivery time for a delivery order.
  Future<void> _updateDeliveryTime(
    String orderId,
    String customerId,
    int deliveryMinutes,
  ) async {
    final deliveryAt = DateTime.now().add(Duration(minutes: deliveryMinutes));

    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'estimatedDeliveryAt': Timestamp.fromDate(deliveryAt),
      'estimatedDeliveryConfirmedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Notify the customer that the seller has set a delivery time.
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': customerId,
      'type': 'delivery_time_set',
      'title': 'Delivery Time Set 🕐',
      'body':
          'Your seller has confirmed the estimated delivery time for your order.',
      'orderId': orderId,
      'read': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: StreamBuilder<QuerySnapshot>(
            stream: _allOrdersStream,
            builder: (context, snapshot) {
              // Count per status for badge
              final allOrders = (snapshot.data?.docs ?? [])
                  .map((d) => d.data() as Map<String, dynamic>)
                  .where((o) {
                final items = (o['items'] as List?) ?? [];
                return items.any((i) => i['sellerId'] == sellerId);
              }).toList();

              return TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: _tabs.map((tab) {
                  final statusKey = tab.$3;
                  // Map tab status to order statuses it covers
                  final count = statusKey == 'on_the_way'
                      ? allOrders.where((o) {
                          final delivery =
                              o['delivery'] as Map<String, dynamic>?;
                          return delivery?['status'] == 'picking_up' ||
                              delivery?['status'] == 'on_the_way';
                        }).length
                      : allOrders
                          .where((o) => (o['status'] ?? '') == statusKey)
                          .length;

                  final label = lang.isSwahili ? tab.$2 : tab.$1;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: statusKey == 'pending'
                                  ? Colors.orange
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          return _OrdersTabView(
            sellerId: sellerId,
            statusFilter: tab.$3,
            lang: lang,
            statusColor: _statusColor,
            statusText: _statusText,
            onUpdateStatus: _updateStatus,
            onSetDeliveryTime: _updateDeliveryTime,
          );
        }).toList(),
      ),
    );
  }
}

// ── Single tab view ───────────────────────────────────────────────────────────
class _OrdersTabView extends StatefulWidget {
  final String sellerId;
  final String statusFilter;
  final LanguageProvider lang;
  final Color Function(String) statusColor;
  final String Function(String, bool) statusText;
  final Future<void> Function(String, String, String, {int? prepMinutes})
      onUpdateStatus;
  final Future<void> Function(String, String, int) onSetDeliveryTime;

  const _OrdersTabView({
    required this.sellerId,
    required this.statusFilter,
    required this.lang,
    required this.statusColor,
    required this.statusText,
    required this.onUpdateStatus,
    required this.onSetDeliveryTime,
  });

  @override
  State<_OrdersTabView> createState() => _OrdersTabViewState();
}

class _OrdersTabViewState extends State<_OrdersTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // keep scroll position when switching tabs

  static const _navy = Color(0xFF1E1B4B);

  late Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    if (widget.statusFilter == 'on_the_way') {
      // on_the_way is filtered client-side by delivery.status
      _stream = FirebaseFirestore.instance.collection('orders').snapshots();
    } else {
      _stream = FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: widget.statusFilter)
          .snapshots();
    }
  }

  @override
  void didUpdateWidget(_OrdersTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusFilter != widget.statusFilter ||
        oldWidget.sellerId != widget.sellerId) {
      _initStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = widget.lang;

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter by seller + status, sort client-side to handle pending timestamps
        var orders = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final items = (data['items'] as List?) ?? [];
          if (!items.any((i) => i['sellerId'] == widget.sellerId)) {
            return false;
          }

          if (widget.statusFilter == 'on_the_way') {
            final delivery = data['delivery'] as Map<String, dynamic>?;
            return delivery?['status'] == 'picking_up' ||
                delivery?['status'] == 'on_the_way';
          }
          return (data['status'] ?? '') == widget.statusFilter;
        }).toList();

        // Sort newest first client-side (handles null createdAt for brand-new orders)
        orders.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
          final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return -1; // null = just created, show first
          if (bTs == null) return 1;
          return bTs.compareTo(aTs);
        });

        if (orders.isEmpty) {
          return _emptyState(lang);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final order = doc.data() as Map<String, dynamic>;
            final myItems = ((order['items'] as List?) ?? [])
                .where((i) => i['sellerId'] == widget.sellerId)
                .toList();
            final status = order['status'] ?? 'pending';
            final createdAt = order['createdAt'] as Timestamp?;
            final fulfillment = order['fulfillment'] ?? 'delivery';
            final isPickup = fulfillment == 'pickup';
            final subtotal = myItems.fold<double>(
              0,
              (acc, i) => acc + ((i['price'] ?? 0) * (i['quantity'] ?? 1)),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  // ── Header ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.statusColor(status).withValues(alpha: 0.06),
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
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.blue.withValues(alpha: 0.1),
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
                                color: widget
                                    .statusColor(status)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.statusText(status, lang.isSwahili),
                                style: TextStyle(
                                  color: widget.statusColor(status),
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

                  // ── Customer info ────────────────────────────────────
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(order['customerId'])
                        .get(),
                    builder: (context, snap) {
                      final customer =
                          snap.data?.data() as Map<String, dynamic>?;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                                  (lang.isSwahili ? 'Mteja' : 'Customer'),
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

                  // ── Items ────────────────────────────────────────────
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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

                  // ── Subtotal + action buttons ─────────────────────────
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang.isSwahili ? 'Jumla' : 'Subtotal',
                              style: TextStyle(color: Colors.grey.shade600),
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

                        // Confirm / Reject — only on New Orders tab
                        if (status == 'pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => widget.onUpdateStatus(
                                    doc.id,
                                    'cancelled',
                                    order['customerId'] ?? '',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
                                  onPressed: () => _confirmWithPrepTime(
                                    context,
                                    doc.id,
                                    order['customerId'] ?? '',
                                    lang,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _navy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    lang.isSwahili ? 'Thibitisha' : 'Confirm',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Set Delivery Time — confirmed delivery orders only
                        if (status == 'confirmed' &&
                            fulfillment == 'delivery' &&
                            order['estimatedDeliveryAt'] == null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _setDeliveryTime(
                                context,
                                doc.id,
                                order['customerId'] ?? '',
                                lang,
                              ),
                              icon: const Icon(Icons.schedule, size: 18),
                              label: Text(
                                lang.isSwahili
                                    ? 'Weka Wakati wa Utoaji'
                                    : 'Set Delivery Time',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3730A3),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],

                        // Delivery time already set — show it on the card
                        if (status == 'confirmed' &&
                            fulfillment == 'delivery' &&
                            order['estimatedDeliveryAt'] != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule,
                                    size: 16, color: Colors.teal.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    () {
                                      final dt = (order['estimatedDeliveryAt']
                                              as Timestamp)
                                          .toDate();
                                      return '${lang.isSwahili ? 'Utoaji' : 'Delivery'}: '
                                          '${dt.day}/${dt.month}/${dt.year} '
                                          '${dt.hour.toString().padLeft(2, '0')}:'
                                          '${dt.minute.toString().padLeft(2, '0')}';
                                    }(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // Allow the seller to update the time
                                GestureDetector(
                                  onTap: () => _setDeliveryTime(
                                    context,
                                    doc.id,
                                    order['customerId'] ?? '',
                                    lang,
                                  ),
                                  child: Icon(Icons.edit,
                                      size: 15, color: Colors.teal.shade600),
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
    );
  }

  // ── Prep-time dialog before confirming ────────────────────────────────────
  Future<void> _confirmWithPrepTime(
    BuildContext context,
    String orderId,
    String customerId,
    LanguageProvider lang,
  ) async {
    const options = [1, 2, 5, 10, 15, 30];
    int selected = 5;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            lang.isSwahili ? 'Muda wa Maandalizi' : 'Preparation Time',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.isSwahili
                    ? 'Inachukua muda gani kuandaa agizo hili?'
                    : 'How long will it take to prepare this order?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((min) {
                  final active = selected == min;
                  return GestureDetector(
                    onTap: () => setModal(() => selected = min),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF1E1B4B)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF1E1B4B)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        min < 60
                            ? '$min ${lang.isSwahili ? 'dak' : 'min'}'
                            : '${min ~/ 60} ${lang.isSwahili ? 'saa' : 'hr'}'
                                '${min % 60 > 0 ? ' ${min % 60}${lang.isSwahili ? 'dak' : 'min'}' : ''}',
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.isSwahili ? 'Ghairi' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1B4B),
                foregroundColor: Colors.white,
              ),
              child: Text(lang.isSwahili ? 'Thibitisha' : 'Confirm'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    await widget.onUpdateStatus(
      orderId,
      'confirmed',
      customerId,
      prepMinutes: selected,
    );
  }

  // ── Delivery-time dialog for confirmed delivery orders ────────────────────
  Future<void> _setDeliveryTime(
    BuildContext context,
    String orderId,
    String customerId,
    LanguageProvider lang,
  ) async {
    // Options in minutes.
    const options = [1, 2, 5, 10, 15, 30];
    int selected = 5;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            lang.isSwahili ? 'Wakati wa Utoaji' : 'Estimated Delivery Time',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.isSwahili
                    ? 'Itachukua muda gani mteja kupokea bidhaa?'
                    : 'How long until the customer receives their order?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((min) {
                  final active = selected == min;
                  String label;
                  if (min < 60) {
                    label = '$min ${lang.isSwahili ? 'dak' : 'min'}';
                  } else if (min % 60 == 0) {
                    label = '${min ~/ 60} ${lang.isSwahili ? 'saa' : 'hr'}';
                  } else {
                    label = '${min ~/ 60}${lang.isSwahili ? 'saa' : 'hr'} '
                        '${min % 60}${lang.isSwahili ? 'dak' : 'min'}';
                  }
                  return GestureDetector(
                    onTap: () => setModal(() => selected = min),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF1E1B4B)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF1E1B4B)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.isSwahili ? 'Ghairi' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1B4B),
                foregroundColor: Colors.white,
              ),
              child: Text(lang.isSwahili ? 'Thibitisha' : 'Confirm'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    await _setDeliveryTimeOnState(context, orderId, customerId, selected, lang);
  }

  Future<void> _setDeliveryTimeOnState(
    BuildContext context,
    String orderId,
    String customerId,
    int minutes,
    LanguageProvider lang,
  ) async {
    try {
      // Access the parent state's method via the widget reference.
      // _OrdersTabView delegates up to SellerOrdersScreen._updateDeliveryTime.
      await widget.onSetDeliveryTime(orderId, customerId, minutes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isSwahili
                ? 'Wakati wa utoaji umewekwa.'
                : 'Delivery time set successfully.'),
            backgroundColor: Colors.green.shade700,
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

  Widget _emptyState(LanguageProvider lang) {
    final messages = {
      'pending': lang.isSwahili ? 'Hakuna maagizo mapya' : 'No new orders',
      'confirmed': lang.isSwahili
          ? 'Hakuna maagizo yaliyothibitishwa'
          : 'No confirmed orders',
      'on_the_way': lang.isSwahili
          ? 'Hakuna maagizo yanayoshughulikiwa'
          : 'No orders in processing',
      'delivered': lang.isSwahili
          ? 'Hakuna maagizo yaliyokamilika'
          : 'No completed orders',
      'cancelled': lang.isSwahili
          ? 'Hakuna maagizo yaliyoghairiwa'
          : 'No cancelled orders',
    };

    final icons = {
      'pending': Icons.inbox_outlined,
      'confirmed': Icons.check_circle_outline,
      'on_the_way': Icons.local_shipping_outlined,
      'delivered': Icons.done_all,
      'cancelled': Icons.cancel_outlined,
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icons[widget.statusFilter] ?? Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            messages[widget.statusFilter] ?? '',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// end of file
