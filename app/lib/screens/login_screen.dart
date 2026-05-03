import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'customer_dashboard.dart';
import 'seller_dashboard.dart';
import 'driver_dashboard.dart';
import 'driver_profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  static const _btnColor = Color(0xFF1A1A1A);
  static const _bgColor = Colors.white;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Read lang here so it's available in the catch block
    final lang = context.read<LanguageProvider>();

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final position = await LocationService().getCurrentLocation();
        if (position != null) {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1',
          );
          final response = await http.get(
            url,
            headers: {'User-Agent': 'ZanSeaFood/1.0'},
          );
          String locationName =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final address = data['address'] as Map<String, dynamic>;
            final neighbourhood =
                address['neighbourhood'] ??
                address['suburb'] ??
                address['quarter'] ??
                address['village'] ??
                address['hamlet'];
            final city =
                address['city'] ??
                address['town'] ??
                address['municipality'] ??
                address['county'];
            locationName = [neighbourhood, city]
                .where((e) => e != null && e.toString().isNotEmpty)
                .toSet()
                .join(', ');
          }
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'location': {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'name': locationName,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              }, SetOptions(merge: true));
        }
      } catch (e) {
        print('Location error: $e');
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] ?? 'customer';

      if (!mounted) return;

      Widget destination;
      if (role == 'seller') {
        destination = const SellerDashboard();
      } else if (role == 'driver') {
        // Check if driver has completed profile
        final profileComplete = doc.data()?['profileComplete'] ?? false;
        destination = profileComplete
            ? const DriverDashboard()
            : const DriverProfileSetupScreen();
      } else {
        destination = const CustomerDashboard();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        String displayMsg;
        if (msg.contains('account_deleted')) {
          displayMsg = lang.isSwahili
              ? 'Akaunti hii imefutwa. Tafadhali wasiliana na msaada.'
              : 'This account has been deleted. Please contact support.';
        } else if (msg.contains('account_banned')) {
          displayMsg = lang.isSwahili
              ? 'Akaunti yako imezuiwa. Tafadhali wasiliana na msaada.'
              : 'Your account has been suspended. Please contact support.';
        } else {
          displayMsg = lang.isSwahili
              ? 'Imeshindwa kuingia. Angalia barua pepe na nywila.'
              : 'Login failed. Check your email and password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(displayMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/zanseafoodlogo.png',
                  height: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  lang.t('welcome_back'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  lang.t('your_marketplace'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: lang.t('enter_email'),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: lang.t('password'),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Remember me + Forget password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          activeColor: _btnColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Text(
                          lang.t('remember_me'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: Text(
                        lang.t('forget_password'),
                        style: const TextStyle(
                          color: _btnColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btnColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            lang.t('login'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.t('no_account'),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(
                        lang.t('register'),
                        style: const TextStyle(
                          color: _btnColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
