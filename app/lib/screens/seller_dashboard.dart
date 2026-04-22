import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'seller_products_page.dart';
import 'profile_screen.dart';
import 'seller_orders_screen.dart';
import 'add_product_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});
  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _currentIndex = 0;
  final _authService = AuthService();
  Map<String, dynamic>? _userData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      if (mounted) setState(() => _userData = data);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pages = [
      _SellerHomePage(
        userData: _userData,
        lang: lang,
        onLogout: _logout,
        onOpenDrawer: _openDrawer,
        onNavigate: (i) => setState(() => _currentIndex = i),
      ),
      SellerProductsPage(lang: lang, onOpenDrawer: _openDrawer),
      SellerOrdersScreen(onOpenDrawer: _openDrawer),
      ProfileScreen(
        themeColor: const Color(0xFF1E1B4B),
        roleIcon: Icons.store,
        onOpenDrawer: _openDrawer,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E1B4B),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: lang.t('dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            activeIcon: const Icon(Icons.inventory_2),
            label: lang.t('my_products'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_bag_outlined),
            activeIcon: const Icon(Icons.shopping_bag),
            label: lang.t('orders'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: lang.t('my_profile'),
          ),
        ],
      ),
      drawer: _buildDrawer(context, lang),
    );
  }

  Widget _buildDrawer(BuildContext context, LanguageProvider lang) {
    final name = _userData?['fullName'] ?? _userData?['username'] ?? '';
    final phone = _userData?['phone'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Drawer(
      child: Container(
        color: const Color(0xFF1E1B4B),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          Text(
                            lang.t('seller_account'),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _drawerTile(
                      context,
                      Icons.home_outlined,
                      lang.t('dashboard'),
                      0,
                    ),
                    _drawerTile(
                      context,
                      Icons.inventory_2_outlined,
                      lang.t('my_products'),
                      1,
                    ),
                    _drawerTile(
                      context,
                      Icons.shopping_bag_outlined,
                      lang.t('orders'),
                      2,
                    ),
                    _drawerTile(
                      context,
                      Icons.person_outline,
                      lang.t('my_profile'),
                      3,
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(
                  lang.t('logout'),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}

class _SellerHomePage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final LanguageProvider lang;
  final VoidCallback onLogout;
  final VoidCallback? onOpenDrawer;
  final ValueChanged<int>? onNavigate;
  const _SellerHomePage({
    this.userData,
    required this.lang,
    required this.onLogout,
    this.onOpenDrawer,
    this.onNavigate,
  });

  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF3730A3);

  String _greeting(LanguageProvider lang) {
    final h = DateTime.now().hour;
    if (h < 12) return lang.isSwahili ? 'Habari za asubuhi' : 'Good morning';
    if (h < 17) return lang.isSwahili ? 'Habari za mchana' : 'Good afternoon';
    return lang.isSwahili ? 'Habari za jioni' : 'Good evening';
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(lang.t('add_product')),
        elevation: 4,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 155,
            pinned: true,
            floating: false,
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed:
                  onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: lang.t('logout'),
                onPressed: onLogout,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, _indigo],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(72, 10, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_greeting(lang)} 👋',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, snap) {
                            final d =
                                snap.data?.data() as Map<String, dynamic>?;
                            final name = d?['fullName'] ?? d?['username'] ?? '';
                            return Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${now.day}/${now.month}/${now.year}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Stats + alert + quick actions + recent orders ──────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .where('sellerId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, productSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .snapshots(),
                      builder: (context, orderSnap) {
                        final productCount = productSnap.data?.docs.length ?? 0;
                        int totalOrders = 0;
                        int pendingOrders = 0;
                        double revenue = 0;
                        if (orderSnap.hasData) {
                          for (final doc in orderSnap.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final items = (data['items'] as List?) ?? [];
                            final mine = items
                                .where((i) => i['sellerId'] == uid)
                                .toList();
                            if (mine.isNotEmpty) {
                              totalOrders++;
                              if (data['status'] == 'pending') pendingOrders++;
                              if (data['status'] == 'delivered') {
                                revenue += mine.fold<double>(
                                  0,
                                  (acc, i) =>
                                      acc +
                                      ((i['price'] ?? 0) *
                                          (i['quantity'] ?? 1)),
                                );
                              }
                            }
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatTile(
                                      icon: Icons.inventory_2_outlined,
                                      label: lang.t('my_products'),
                                      value: '$productCount',
                                      color: _indigo,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatTile(
                                      icon: Icons.shopping_bag_outlined,
                                      label: lang.t('orders'),
                                      value: '$totalOrders',
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatTile(
                                      icon: Icons.pending_actions_outlined,
                                      label: lang.isSwahili
                                          ? 'Zinasubiri'
                                          : 'Pending',
                                      value: '$pendingOrders',
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatTile(
                                      icon: Icons.attach_money_outlined,
                                      label: lang.t('earnings'),
                                      value: 'TShs ${_compact(revenue)}',
                                      color: Colors.green,
                                      smallValue: true,
                                    ),
                                  ),
                                ],
                              ),
                              // Pending alert
                              if (pendingOrders > 0) ...[
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: () => onNavigate?.call(2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_active,
                                          color: Colors.orange.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            lang.isSwahili
                                                ? 'Una maagizo $pendingOrders yanayosubiri uthibitisho'
                                                : 'You have $pendingOrders order${pendingOrders > 1 ? 's' : ''} awaiting confirmation',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.orange.shade600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                // Recent Orders header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isSwahili
                            ? 'Maagizo ya Hivi Karibuni'
                            : 'Recent Orders',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onNavigate?.call(2),
                        child: Text(
                          lang.isSwahili ? 'Ona Zote' : 'See All',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _indigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Recent Orders list
                _RecentOrdersList(uid: uid, lang: lang),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat tile ──────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool smallValue;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: smallValue ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent orders list ─────────────────────────────────────────────────────
class _RecentOrdersList extends StatelessWidget {
  final String uid;
  final LanguageProvider lang;
  const _RecentOrdersList({required this.uid, required this.lang});

  static const _navy = Color(0xFF1E1B4B);

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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) return const SizedBox();

        final orders = snapshot.data!.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final items = (data['items'] as List?) ?? [];
              return items.any((i) => i['sellerId'] == uid);
            })
            .take(5)
            .toList();

        if (orders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lang.isSwahili ? 'Hakuna maagizo bado' : 'No orders yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final order = doc.data() as Map<String, dynamic>;
            final items = (order['items'] as List?) ?? [];
            final mine = items.where((i) => i['sellerId'] == uid).toList();
            final status = order['status'] ?? 'pending';
            final createdAt = order['createdAt'] as Timestamp?;
            final subtotal = mine.fold<double>(
              0,
              (acc, i) => acc + ((i['price'] ?? 0) * (i['quantity'] ?? 1)),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_outlined,
                      color: _statusColor(status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  status,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(order['customerId'])
                              .get(),
                          builder: (context, snap) {
                            final c =
                                snap.data?.data() as Map<String, dynamic>?;
                            return Text(
                              c?['fullName'] ??
                                  c?['username'] ??
                                  (lang.isSwahili ? 'Mteja' : 'Customer'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              createdAt != null
                                  ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                                  : '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}
