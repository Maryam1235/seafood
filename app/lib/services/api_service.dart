import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Talks to the self-hosted NestJS backend (seafood-api), which replaces the
/// Firebase Cloud Functions for ClickPesa payments.
///
/// The app always talks to the remote production server. The URL can still be
/// overridden at build/run time if ever needed, e.g. to point at a staging box:
///   flutter run --dart-define=API_BASE_URL=https://staging.arifa.org
/// but it defaults to the live server so release builds need no extra flags.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.arifa.org',
  );

  /// POST a JSON body to [path], attaching the current user's Firebase ID token
  /// so the server can verify who is calling. Returns the decoded JSON body.
  /// Throws [ApiException] on a non-2xx response or if the user is signed out.
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ApiException('You must be signed in.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw ApiException('Could not obtain an auth token. Please sign in again.');
    }

    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );

    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = decoded['message']?.toString() ?? 'Request failed (${res.statusCode})';
      throw ApiException(message, res.statusCode);
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
