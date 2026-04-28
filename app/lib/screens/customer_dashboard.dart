import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'browse_seafood_screen.dart';
import 'orders_screen.dart';
import 'order_history_screen.dart';
import 'delivery_personnel_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  // Page indices:
  // 0 = Browse Seafood
  // 1 = My Orders
  // 2 = Order History
  // 3 = Delivery Personnel
  // 4 = My Profile
  int _currentIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();

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
      BrowseSeafoodScreen(onOpenDrawer: _openDrawer), // 0
      OrdersScreen(onOpenDrawer: _openDrawer), // 1
      OrderHistoryScreen(onOpenDrawer: _openDrawer), // 2
      DeliveryPersonnelScreen(onOpenDrawer: _openDrawer), // 3
      ProfileScreen(
        themeColor: const Color(0xFF3730A3),
        roleIcon: Icons.person,
        onOpenDrawer: _openDrawer,
      ), // 4
    ];

    // Bottom nav maps to: 0=Browse, 1=Orders, 2=Profile
    int bottomIndex;
    if (_currentIndex == 0) {
      bottomIndex = 0;
    } else if (_currentIndex == 1) {
      bottomIndex = 1;
    } else if (_currentIndex == 4) {
      bottomIndex = 2;
    } else {
      bottomIndex = 1; // history/personnel stay highlighted under Orders
    }

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomIndex,
        onTap: (i) => setState(() {
          if (i == 0) _currentIndex = 0;
          if (i == 1) _currentIndex = 1;
          if (i == 2) _currentIndex = 4;
        }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3730A3),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.set_meal_outlined),
            activeIcon: const Icon(Icons.set_meal),
            label: lang.t('browse_seafood'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: lang.t('my_orders'),
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
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Container(
        color: const Color(0xFF1E1B4B),
        child: SafeArea(
          child: Column(
            children: [
              // Header — stream so it updates as soon as Firestore responds
              StreamBuilder<DocumentSnapshot>(
                stream: user == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                  final name = data['fullName'] ?? data['username'] ?? '';
                  final username = data['username'] ?? '';
                  final phone = data['phone'] ?? '';
                  final email = user?.email ?? data['email'] ?? '';
                  final initial = name.isNotEmpty
                      ? name[0].toUpperCase()
                      : (email.isNotEmpty ? email[0].toUpperCase() : 'C');

                  return Container(
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
                              if (name.isNotEmpty)
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
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
                  );
                },
              ),
              const Divider(color: Colors.white24),

              // Nav items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _drawerTile(
                      context,
                      Icons.set_meal_outlined,
                      lang.t('browse_seafood'),
                      0,
                    ),
                    _drawerTile(
                      context,
                      Icons.receipt_long_outlined,
                      lang.t('my_orders'),
                      1,
                    ),
                    _drawerTile(
                      context,
                      Icons.history_outlined,
                      lang.t('order_history'),
                      2,
                    ),
                    _drawerTile(
                      context,
                      Icons.delivery_dining_outlined,
                      lang.t('delivery_personnel'),
                      3,
                    ),
                    _drawerTile(
                      context,
                      Icons.person_outline,
                      lang.t('my_profile'),
                      4,
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
