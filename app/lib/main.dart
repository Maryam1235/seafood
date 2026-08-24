import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final languageProvider = LanguageProvider();
  await languageProvider.init();

  runApp(MyApp(languageProvider: languageProvider));

  // Init notifications AFTER the app is rendered so it never causes a black
  // screen. Failures here are non-fatal — the app works without push alerts.
  NotificationService.init().catchError(
    (e) => debugPrint('[NotificationService] init failed: $e'),
  );
}

class MyApp extends StatelessWidget {
  final LanguageProvider languageProvider;
  const MyApp({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: languageProvider,
      child: MaterialApp(
        title: 'ZanSeaFood',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
