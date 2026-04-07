import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;
  final _authService = AuthService();
  Map<String, dynamic>? _userData;

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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pages = [
      _HomePage(userData: _userData, lang: lang, onLogout: _logout),
      _OrdersPage(lang: lang),
      _FavoritesPage(lang: lang),
      ProfileScreen(themeColor: Colors.blue.shade700, roleIcon: Icons.person),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: lang.t('browse_seafood'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long),
            label: lang.t('my_orders'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: lang.t('favorites'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: lang.t('my_profile'),
          ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final LanguageProvider lang;
  final VoidCallback onLogout;
  const _HomePage({this.userData, required this.lang, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
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
            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('browse_seafood'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          lang.t('browse_seafood'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
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
                        icon: Icons.set_meal,
                        label: lang.t('browse_seafood'),
                        color: Colors.blue,
                      ),
                      _QuickCard(
                        icon: Icons.local_offer,
                        label: 'Offers',
                        color: Colors.orange,
                      ),
                      _QuickCard(
                        icon: Icons.receipt_long,
                        label: lang.t('my_orders'),
                        color: Colors.green,
                      ),
                      _QuickCard(
                        icon: Icons.support_agent,
                        label: 'Support',
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
        title: Text(lang.t('my_orders')),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
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

class _FavoritesPage extends StatelessWidget {
  final LanguageProvider lang;
  const _FavoritesPage({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('favorites')),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 80, color: Colors.grey.shade300),
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

class _ProfilePage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final LanguageProvider lang;
  final VoidCallback onLogout;
  const _ProfilePage({
    this.userData,
    required this.lang,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('my_profile')),
        backgroundColor: Colors.blue.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, size: 60, color: Colors.blue.shade700),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              userData?['username'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              userData?['email'] ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(
            icon: Icons.person,
            label: 'Full Name',
            value: userData?['fullName'] ?? '',
          ),
          _InfoTile(
            icon: Icons.phone,
            label: 'Phone',
            value: userData?['phone'] ?? '',
          ),
          _InfoTile(
            icon: Icons.email,
            label: 'Email',
            value: userData?['email'] ?? '',
          ),
          _InfoTile(
            icon: Icons.location_on,
            label: 'Location',
            value: userData?['location']?['name'] ?? 'N/A',
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: Text(lang.t('logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
