import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'profile_screen.dart';
import 'browse_seafood_screen.dart';
import 'orders_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pages = [
      const BrowseSeafoodScreen(),
      const OrdersScreen(),
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
            icon: const Icon(Icons.set_meal),
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

class _FavoritesPage extends StatelessWidget {
  final LanguageProvider lang;
  const _FavoritesPage({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('favorites')),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline, size: 80, color: Colors.grey.shade300),
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
