import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserCredential> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String phone,
    required String role, // 'customer' or 'seller'
  }) async {
    try {
      // Create user account
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      print('User created: ${userCredential.user!.uid}');

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'username': username,
        'phone': '+255${phone.replaceAll(RegExp(r'^0'), '')}',
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('User data saved to Firestore');

      return userCredential;
    } catch (e) {
      print('Registration error: $e');
      throw Exception(e.toString());
    }
  }

  // Login with email and password
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
}
