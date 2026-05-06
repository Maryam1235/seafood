import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'driver_notifications_screen.dart';
import 'driver_deliveries_screen.dart';
import 'driver_messages_screen.dart';
import 'settings_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});
  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;
  final _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isOnline = false;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final pages = [
      _DriverHomePage(
        userData: _userData,
        lang: lang,
        isOnline: _isOnline,
        onToggle: (v) => setState(() => _isOnline = v),
        onLogout: _logout,
        onOpenDrawer: _openDrawer,
      ),
      DriverNotificationsScreen(onOpenDrawer: _openDrawer), // 1
      ActiveDeliveryScreen(onOpenDrawer: _openDrawer), // 2
      AvailableOrdersScreen(onOpenDrawer: _openDrawer), // 3
      DeliveryHistoryScreen(onOpenDrawer: _openDrawer), // 4
      _EarningsPage(lang: lang, onOpenDrawer: _openDrawer), // 5
      ProfileScreen(
        themeColor: Colors.teal.shade700,
        roleIcon: Icons.delivery_dining,
        onOpenDrawer: _openDrawer,
      ), // 6
      DriverMessagesScreen(onOpenDrawer: _openDrawer), // 7
      SettingsScreen(
        themeColor: Colors.teal.shade700,
        onOpenDrawer: _openDrawer,
      ), // 8
    ];

    // Bottom nav: 0=Home, 1=Alerts, 2=Messages, 3=Profile
    int bottomIndex;
    if (_currentIndex == 0) {
      bottomIndex = 0;
    } else if (_currentIndex == 1) {
      bottomIndex = 1;
    } else if (_currentIndex == 7) {
      bottomIndex = 2;
    } else if (_currentIndex == 6) {
      bottomIndex = 3;
    } else {
      bottomIndex =
          0; // active/available/history/earnings/settings → keep Home highlighted
    }

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(index: _currentIndex, children: pages),

      // 4-item bottom nav
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomIndex,
        onTap: (i) => setState(() {
          if (i == 0) _currentIndex = 0;
          if (i == 1) _currentIndex = 1;
          if (i == 2) _currentIndex = 7;
          if (i == 3) _currentIndex = 6;
        }),
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: lang.t('home'),
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Stack(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: lang.isSwahili ? 'Arifa' : 'Alerts',
          ),
          // Messages tab with unread badge
          BottomNavigationBarItem(
            icon: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: uid)
                  .snapshots(),
              builder: (context, chatSnap) {
                final hasChats = chatSnap.data?.docs.isNotEmpty ?? false;
                return Stack(
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    if (hasChats)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            activeIcon: const Icon(Icons.chat_bubble),
            label: lang.isSwahili ? 'Ujumbe' : 'Messages',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: lang.t('my_profile'),
          ),
        ],
      ),

      // Sidebar drawer with all 5 nav items
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF004D40),
          child: SafeArea(
            child: Column(
              children: [
                // Driver header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Text(
                          (_userData?['username'] ?? '?')
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
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
                              _userData?['fullName'] ??
                                  _userData?['username'] ??
                                  '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _userData?['phone'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: _isOnline
                                      ? Colors.greenAccent
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isOnline
                                      ? (lang.isSwahili
                                            ? 'Mtandaoni'
                                            : 'Online')
                                      : (lang.isSwahili ? 'Nje' : 'Offline'),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
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
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _drawerTile(
                        context,
                        Icons.home_outlined,
                        lang.t('home'),
                        0,
                      ),
                      _drawerTile(
                        context,
                        Icons.notifications_outlined,
                        lang.isSwahili ? 'Arifa' : 'Alerts',
                        1,
                        uid: uid,
                      ),
                      _drawerTile(
                        context,
                        Icons.local_shipping_outlined,
                        lang.t('active_delivery'),
                        2,
                      ),
                      _drawerTile(
                        context,
                        Icons.assignment_outlined,
                        lang.isSwahili
                            ? 'Maagizo Yanayopatikana'
                            : 'Available Orders',
                        3,
                      ),
                      _drawerTile(
                        context,
                        Icons.history_outlined,
                        lang.t('delivery_history'),
                        4,
                      ),
                      _drawerTile(
                        context,
                        Icons.attach_money_outlined,
                        lang.t('earnings'),
                        5,
                      ),
                      _drawerTile(
                        context,
                        Icons.chat_bubble_outline,
                        lang.isSwahili ? 'Ujumbe' : 'Messages',
                        7,
                        uid: uid,
                        isMessages: true,
                      ),
                      _drawerTile(
                        context,
                        Icons.person_outline,
                        lang.t('my_profile'),
                        6,
                      ),
                      _drawerTile(
                        context,
                        Icons.settings_outlined,
                        lang.t('settings'),
                        8,
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
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context,
    IconData icon,
    String label,
    int index, {
    String? uid,
    bool isMessages = false,
  }) {
    final selected = _currentIndex == index;
    return ListTile(
      leading: Stack(
        children: [
          Icon(
            icon,
            color: selected ? Colors.greenAccent : Colors.white70,
            size: 24,
          ),
          if (uid != null && index == 1)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                if (count == 0) return const SizedBox();
                return Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (uid != null && isMessages)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: uid)
                  .snapshots(),
              builder: (context, snap) {
                final hasChats = (snap.data?.docs.isNotEmpty ?? false);
                if (!hasChats) return const SizedBox();
                return Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.greenAccent : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      selected: selected,
      selectedTileColor: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}

class _DriverHomePage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final LanguageProvider lang;
  final bool isOnline;
  final ValueChanged<bool> onToggle;
  final VoidCallback onLogout;
  final VoidCallback onOpenDrawer;
  const _DriverHomePage({
    this.userData,
    required this.lang,
    required this.isOnline,
    required this.onToggle,
    required this.onLogout,
    required this.onOpenDrawer,
  });

  static const _teal = Color(0xFF00695C);
  static const _navy = Color(0xFF1E1B4B);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t('welcome_back'),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              userData?['username'] ?? '',
              style: const TextStyle(
                fontSize: 16,
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
            // Header with online toggle + stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Online toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                shape: BoxShape.circle,
                                boxShadow: isOnline
                                    ? [
                                        BoxShadow(
                                          color: Colors.greenAccent.withOpacity(
                                            0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isOnline
                                  ? (lang.isSwahili
                                        ? 'Uko Mtandaoni'
                                        : 'You are Online')
                                  : (lang.isSwahili
                                        ? 'Uko Nje'
                                        : 'You are Offline'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: isOnline,
                          onChanged: onToggle,
                          activeThumbColor: Colors.greenAccent,
                          activeTrackColor: Colors.greenAccent.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('delivery.driverId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snap) {
                      final orders = snap.data?.docs ?? [];
                      final active = orders
                          .where(
                            (d) =>
                                (d.data() as Map)['delivery']?['status'] ==
                                'on_the_way',
                          )
                          .length;
                      final delivered = orders
                          .where(
                            (d) => (d.data() as Map)['status'] == 'delivered',
                          )
                          .length;
                      final earnings = orders
                          .where(
                            (d) => (d.data() as Map)['status'] == 'delivered',
                          )
                          .fold<double>(
                            0,
                            (sum, d) =>
                                sum +
                                (((d.data() as Map)['delivery']?['cost'] ?? 0)
                                        as num)
                                    .toDouble(),
                          );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCard(
                            label: lang.t('active_delivery'),
                            value: '$active',
                            icon: Icons.local_shipping,
                          ),
                          _StatCard(
                            label: lang.t('delivery_history'),
                            value: '$delivered',
                            icon: Icons.history,
                          ),
                          _StatCard(
                            label: lang.t('earnings'),
                            value: 'TShs ${earnings.toStringAsFixed(0)}',
                            icon: Icons.attach_money,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Available Orders
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isSwahili
                            ? 'Maagizo Yanayopatikana'
                            : 'Available Orders',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          lang.isSwahili ? 'Tazama Yote' : 'See All',
                          style: const TextStyle(
                            color: _teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              lang.isSwahili
                                  ? 'Hakuna maagizo sasa'
                                  : 'No available orders',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        );
                      }
                      final orders = snap.data!.docs.take(3).toList();
                      return Column(
                        children: orders.map((doc) {
                          final order = doc.data() as Map<String, dynamic>;
                          final items = (order['items'] as List?) ?? [];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: _teal,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
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
                                      Text(
                                        '${items.length} ${lang.isSwahili ? 'bidhaa' : 'items'}',
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
                                      'TShs ${order['total']?.toStringAsFixed(0) ?? '0'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _navy,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        lang.isSwahili
                                            ? 'Inasubiri'
                                            : 'Pending',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Recent Deliveries
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isSwahili
                            ? 'Utoaji wa Hivi Karibuni'
                            : 'Recent Deliveries',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          lang.isSwahili ? 'Tazama Yote' : 'See All',
                          style: const TextStyle(
                            color: _teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('delivery.driverId', isEqualTo: uid)
                        .where('status', isEqualTo: 'delivered')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              lang.isSwahili
                                  ? 'Hakuna historia bado'
                                  : 'No deliveries yet',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        );
                      }
                      final orders = snap.data!.docs.take(3).toList();
                      return Column(
                        children: orders.map((doc) {
                          final order = doc.data() as Map<String, dynamic>;
                          final delivery =
                              order['delivery'] as Map<String, dynamic>?;
                          final deliveredAt =
                              delivery?['deliveredAt'] as Timestamp?;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green.shade600,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
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
                                Text(
                                  'TShs ${delivery?['cost']?.toStringAsFixed(0) ?? '0'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
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
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          textAlign: TextAlign.center,
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

class _DeliveriesPage extends StatelessWidget {
  final LanguageProvider lang;
  final VoidCallback? onOpenDrawer;
  const _DeliveriesPage({required this.lang, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('active_delivery')),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 80, color: Colors.grey.shade300),
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

class _EarningsPage extends StatelessWidget {
  final LanguageProvider lang;
  final VoidCallback? onOpenDrawer;
  const _EarningsPage({required this.lang, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('earnings')),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money, size: 80, color: Colors.grey.shade300),
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
