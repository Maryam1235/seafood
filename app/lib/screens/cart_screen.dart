import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/cart_service.dart';
import 'delivery_selection_screen.dart';
import 'customer_dashboard.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const _navy = Color(0xFF1E1B4B);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final cartService = CartService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(lang.isSwahili ? 'Magulio Yangu' : 'My Cart'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartService.cartStream(),
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
                    Icons.shopping_cart_outlined,
                    size: 90,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isSwahili
                        ? 'Magulio yako ni tupu'
                        : 'Your cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.isSwahili
                        ? 'Ongeza bidhaa kutoka kwenye orodha'
                        : 'Add products from the browse screen',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data!.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();
          final total = items.fold<double>(
            0,
            (acc, item) =>
                acc + ((item['price'] ?? 0) * (item['quantity'] ?? 1)),
          );

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final qty = item['quantity'] ?? 1;
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
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: item['imageUrl'] != null
                                  ? Image.network(
                                      item['imageUrl'],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey.shade100,
                                      child: Icon(
                                        Icons.set_meal,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'TShs ${item['price']?.toStringAsFixed(0)} / ${item['unit']}',
                                    style: const TextStyle(
                                      color: _navy,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _qtyBtn(
                                        Icons.remove,
                                        () => cartService.updateQuantity(
                                          item['id'],
                                          qty - 1,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(
                                              item['productId'] ?? item['id'],
                                            )
                                            .get(),
                                        builder: (context, stockSnap) {
                                          final stock = stockSnap.hasData
                                              ? ((stockSnap.data!.data()
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >?)?['stock'] ??
                                                        0)
                                                    as num
                                              : double.infinity;
                                          final atMax = qty >= stock;
                                          return _qtyBtn(
                                            Icons.add,
                                            atMax
                                                ? null
                                                : () => cartService
                                                      .updateQuantity(
                                                        item['id'],
                                                        qty + 1,
                                                        maxStock: stock
                                                            .toDouble(),
                                                      ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Subtotal + delete
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TShs ${((item['price'] ?? 0) * qty).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _navy,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () =>
                                      cartService.removeFromCart(item['id']),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade400,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Order summary + checkout
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang.isSwahili ? 'Jumla' : 'Total',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'TShs ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _checkout(context, items, total, lang, cartService),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          lang.isSwahili ? 'Tuma Agizo' : 'Place Order',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? Colors.grey.shade300 : _navy,
        ),
      ),
    );
  }

  Future<void> _checkout(
    BuildContext context,
    List<Map<String, dynamic>> items,
    double total,
    LanguageProvider lang,
    CartService cartService,
  ) async {
    // Step 1 — confirm order
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.isSwahili ? 'Thibitisha Agizo' : 'Confirm Order'),
        content: Text(
          lang.isSwahili
              ? 'Jumla: TShs ${total.toStringAsFixed(0)}\nUnataka kutuma agizo?'
              : 'Total: TShs ${total.toStringAsFixed(0)}\nDo you want to place this order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.isSwahili ? 'Ghairi' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
            ),
            child: Text(lang.isSwahili ? 'Tuma' : 'Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Step 2 — place order in Firestore (created as 'pending'; the fulfillment
    // sheet below advances it once the customer chooses delivery or pickup)
    final orderId = await cartService.placeOrder(items, total);

    // Step 3 — notify sellers (background push + in-app notification)
    await cartService.notifySellers(
      orderId: orderId,
      items: items,
      total: total,
    );

    if (!context.mounted) return;

    // Step 4 — choose fulfillment right away: Delivery routes to driver
    // selection + payment, Pickup confirms without an online payment.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FulfillmentSheet(
        orderId: orderId,
        orderTotal: total,
        lang: lang,
      ),
    );
  }
}

// ── Fulfillment choice bottom sheet ──────────────────────────────────────────
class _FulfillmentSheet extends StatefulWidget {
  final String orderId;
  final double orderTotal;
  final LanguageProvider lang;

  const _FulfillmentSheet({
    required this.orderId,
    required this.orderTotal,
    required this.lang,
  });

  @override
  State<_FulfillmentSheet> createState() => _FulfillmentSheetState();
}

class _FulfillmentSheetState extends State<_FulfillmentSheet> {
  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF3730A3);
  bool _isLoading = false;

  Future<void> _confirmPickup() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
            'fulfillment': 'pickup',
            'grandTotal': widget.orderTotal,
            'status': 'confirmed',
          });
      if (mounted) {
        // Close sheet, then show pickup success screen
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => _PickupConfirmedScreen(lang: widget.lang),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            lang.isSwahili
                ? 'Jinsi ya Kupokea?'
                : 'How do you want to receive?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            lang.isSwahili
                ? 'Chagua utoaji au kuja kuchukua mwenyewe'
                : 'Choose delivery or pick up yourself',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Order total pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_outlined, size: 16, color: _navy),
                const SizedBox(width: 6),
                Text(
                  '${lang.isSwahili ? 'Jumla ya Bidhaa' : 'Order Total'}: TShs ${widget.orderTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Delivery option
          _OptionCard(
            icon: Icons.delivery_dining,
            iconColor: _indigo,
            title: lang.isSwahili ? 'Utoaji' : 'Delivery',
            subtitle: lang.isSwahili
                ? 'Chagua dereva — bei inakokotolewa kwa umbali'
                : 'Choose a driver — cost based on distance',
            badge: lang.isSwahili ? 'Ada ya ziada' : 'Extra fee',
            badgeColor: Colors.orange,
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop(); // close the sheet
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => DeliverySelectionScreen(
                    orderId: widget.orderId,
                    orderTotal: widget.orderTotal,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Pickup option
          _OptionCard(
            icon: Icons.storefront_outlined,
            iconColor: Colors.green.shade700,
            title: lang.isSwahili ? 'Kuja Kuchukua' : 'Pick Up Yourself',
            subtitle: lang.isSwahili
                ? 'Nenda mwenyewe kwa muuzaji kuchukua agizo lako'
                : "Go to the seller's location to collect your order",
            badge: lang.isSwahili ? 'Bila ada' : 'Free',
            badgeColor: Colors.green,
            onTap: _isLoading ? null : _confirmPickup,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────────
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade200
                : iconColor.withValues(alpha: 0.35),
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
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 26),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: disabled
                              ? Colors.grey.shade400
                              : const Color(0xFF111827),
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
            Icon(
              Icons.chevron_right,
              color: disabled ? Colors.grey.shade300 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pickup confirmed screen ───────────────────────────────────────────────────
class _PickupConfirmedScreen extends StatelessWidget {
  final LanguageProvider lang;
  const _PickupConfirmedScreen({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                lang.isSwahili ? 'Agizo Limetumwa!' : 'Order Placed!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.isSwahili
                    ? 'Agizo lako limethibitishwa.\nTafadhali nenda kwa muuzaji kuchukua bidhaa zako.'
                    : 'Your order has been confirmed.\nPlease go to the seller\'s location to collect your items.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang.isSwahili ? 'Kuja Kuchukua' : 'Pick Up',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerDashboard(initialIndex: 1),
                    ),
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1B4B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    lang.isSwahili ? 'Tazama Maagizo' : 'View My Orders',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
