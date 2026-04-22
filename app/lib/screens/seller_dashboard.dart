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
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
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
                      Icons.dashboard_outlined,
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
  const _SellerHomePage({
    this.userData,
    required this.lang,
    required this.onLogout,
    this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t('welcome_back'),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            Text(
              userData?['username'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where(
                    'sellerId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .snapshots(),
              builder: (context, productSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .snapshots(),
                  builder: (context, orderSnap) {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final productCount = productSnap.data?.docs.length ?? 0;
                    int orderCount = 0;
                    double earnings = 0;
                    if (orderSnap.hasData) {
                      for (final doc in orderSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final items = (data['items'] as List?) ?? [];
                        final myItems = items
                            .where((i) => i['sellerId'] == uid)
                            .toList();
                        if (myItems.isNotEmpty) {
                          orderCount++;
                          if (data['status'] == 'delivered') {
                            earnings += myItems.fold<double>(
                              0,
                              (sum, i) =>
                                  sum +
                                  ((i['price'] ?? 0) * (i['quantity'] ?? 1)),
                            );
                          }
                        }
                      }
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCard(
                            label: lang.t('my_products'),
                            value: '$productCount',
                            icon: Icons.inventory,
                          ),
                          _StatCard(
                            label: lang.t('orders'),
                            value: '$orderCount',
                            icon: Icons.shopping_bag,
                          ),
                          _StatCard(
                            label: lang.t('earnings'),
                            value: 'TShs ${earnings.toStringAsFixed(0)}',
                            icon: Icons.attach_money,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('seller_account'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _QuickCard(
                        icon: Icons.add_business,
                        label: lang.t('add_product'),
                        color: Colors.orange,
                      ),
                      _QuickCard(
                        icon: Icons.inventory,
                        label: lang.t('my_products'),
                        color: Colors.blue,
                      ),
                      _QuickCard(
                        icon: Icons.shopping_bag,
                        label: lang.t('orders'),
                        color: Colors.green,
                      ),
                      _QuickCard(
                        icon: Icons.analytics,
                        label: lang.t('sales_report'),
                        color: Colors.purple,
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
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _OrdersPage extends StatelessWidget {
  final LanguageProvider lang;
  const _OrdersPage({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('orders')),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              lang.t('coming_soon'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
