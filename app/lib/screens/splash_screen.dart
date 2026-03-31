import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'language_screen.dart';
import 'login_screen.dart';
import 'customer_dashboard.dart';
import 'seller_dashboard.dart';
import 'driver_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final position = await LocationService().getCurrentLocation();
        final user = FirebaseAuth.instance.currentUser;
        if (position != null && user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'location': {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              });
        }
      } catch (_) {}
      _navigate();
    });
  }

  Future<void> _navigate() async {
    // Check if language has been selected before
    final prefs = await SharedPreferences.getInstance();
    final hasLanguage = prefs.getString('language') != null;

    if (!mounted) return;

    // If no language selected yet, go to language screen
    if (!hasLanguage) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageScreen()),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final role = doc.data()?['role'] ?? 'customer';

    Widget destination;
    if (role == 'seller') {
      destination = const SellerDashboard();
    } else if (role == 'driver') {
      destination = const DriverDashboard();
    } else {
      destination = const CustomerDashboard();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/zanseafoodlogo.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 24),
                const Text(
                  'ZanSeaFood',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fresh Seafood Delivered to You',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.blue.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
