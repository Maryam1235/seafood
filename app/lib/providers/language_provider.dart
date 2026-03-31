import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _language = 'en';

  String get language => _language;
  bool get isSwahili => _language == 'sw';

  LanguageProvider();

  // Call this before runApp to ensure language is loaded synchronously
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  String t(String key) {
    return _translations[_language]?[key] ?? _translations['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Login
      'welcome_back': 'Welcome Back',
      'your_marketplace': 'Your fresh seafood marketplace.\nLogin to continue.',
      'enter_email': 'Enter your email',
      'password': 'Password',
      'remember_me': 'Remember me',
      'forget_password': 'Forget Password',
      'login': 'Login',
      'no_account': "Don't have an account? ",
      'register': 'Register',

      // Register
      'create_account': 'Create Account',
      'sign_up': 'Sign up to get started',
      'full_name': 'Full Name',
      'username': 'Username',
      'phone': 'Phone Number',
      'email': 'Email',
      'confirm_password': 'Confirm Password',
      'already_account': 'Already have an account? ',
      'customer': 'Customer',
      'seller': 'Seller',
      'driver': 'Driver',
      'passwords_no_match': 'Passwords do not match',
      'reg_success': 'Registration successful! Please login.',
      'reg_failed': 'Registration failed: ',

      // Forgot password
      'reset_password': 'Reset Password',
      'reset_subtitle': "Enter your email and we'll send you a reset link",
      'send_reset': 'Send Reset Link',
      'back_login': 'Back to Login',
      'email_sent': 'Email Sent!',
      'resend': 'Resend Email',
      'next_steps': 'Next steps:',
      'step1': 'Open your email inbox',
      'step2': 'Click the reset link in the email',
      'step3': 'Set your new password',
      'step4': 'Come back and login',

      // Dashboards
      'welcome': 'Welcome',
      'customer_account': 'Customer Account',
      'seller_account': 'Seafood Seller Account',
      'driver_account': 'Delivery Driver',
      'logout': 'Logout',
      'browse_seafood': 'Browse Seafood',
      'my_orders': 'My Orders',
      'favorites': 'Favorites',
      'my_profile': 'My Profile',
      'add_product': 'Add Product',
      'my_products': 'My Products',
      'orders': 'Orders',
      'sales_report': 'Sales Report',
      'available_orders': 'Available Orders',
      'active_delivery': 'Active Delivery',
      'delivery_history': 'Delivery History',
      'earnings': 'Earnings',
      'online': 'You are Online',
      'offline': 'You are Offline',
      'coming_soon': 'Coming Soon',
    },
    'sw': {
      // Login
      'welcome_back': 'Karibu Tena',
      'your_marketplace': 'Soko lako la samaki safi.\nIngia kuendelea.',
      'enter_email': 'Ingiza barua pepe yako',
      'password': 'Nywila',
      'remember_me': 'Nikumbuke',
      'forget_password': 'Umesahau Nywila',
      'login': 'Ingia',
      'no_account': 'Huna akaunti? ',
      'register': 'Jisajili',

      // Register
      'create_account': 'Fungua Akaunti',
      'sign_up': 'Jisajili kuanza',
      'full_name': 'Jina Kamili',
      'username': 'Jina la Mtumiaji',
      'phone': 'Nambari ya Simu',
      'email': 'Barua Pepe',
      'confirm_password': 'Thibitisha Nywila',
      'already_account': 'Una akaunti tayari? ',
      'customer': 'Mteja',
      'seller': 'Muuzaji',
      'driver': 'Dereva',
      'passwords_no_match': 'Nywila hazifanani',
      'reg_success': 'Usajili umefanikiwa! Tafadhali ingia.',
      'reg_failed': 'Usajili umeshindwa: ',

      // Forgot password
      'reset_password': 'Weka Upya Nywila',
      'reset_subtitle':
          'Ingiza barua pepe yako na tutakutumia kiungo cha kuweka upya',
      'send_reset': 'Tuma Kiungo',
      'back_login': 'Rudi Kuingia',
      'email_sent': 'Barua Pepe Imetumwa!',
      'resend': 'Tuma Tena',
      'next_steps': 'Hatua zinazofuata:',
      'step1': 'Fungua kisanduku chako cha barua pepe',
      'step2': 'Bonyeza kiungo cha kuweka upya',
      'step3': 'Weka nywila yako mpya',
      'step4': 'Rudi na uingie',

      // Dashboards
      'welcome': 'Karibu',
      'customer_account': 'Akaunti ya Mteja',
      'seller_account': 'Akaunti ya Muuzaji wa Samaki',
      'driver_account': 'Dereva wa Utoaji',
      'logout': 'Toka',
      'browse_seafood': 'Tazama Samaki',
      'my_orders': 'Maagizo Yangu',
      'favorites': 'Vipendwa',
      'my_profile': 'Wasifu Wangu',
      'add_product': 'Ongeza Bidhaa',
      'my_products': 'Bidhaa Zangu',
      'orders': 'Maagizo',
      'sales_report': 'Ripoti ya Mauzo',
      'available_orders': 'Maagizo Yanayopatikana',
      'active_delivery': 'Utoaji Unaoendelea',
      'delivery_history': 'Historia ya Utoaji',
      'earnings': 'Mapato',
      'online': 'Uko Mtandaoni',
      'offline': 'Uko Nje ya Mtandao',
      'coming_soon': 'Inakuja Hivi Karibuni',
    },
  };
}
