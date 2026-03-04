import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Firebase handles persistence automatically
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ================= SIGN UP =================
  Future<User?> signUp(
    String email,
    String password,
    String mobile,
    BuildContext context,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user profile
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'mobile': mobile,
        'password': password, // ⚠️ Security Risk: Saving password in plain text
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save FCM Token
      await FcmService().setupToken(result.user!.uid);

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;

      if (e.code == 'email-already-in-use') {
        message = 'Email already registered. Please log in.';
      } else if (e.code == 'weak-password') {
        message = 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else {
        message = e.message ?? 'Sign up failed';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      return null;
    }
  }

  // ================= SIGN IN =================
  Future<User?> signIn(
    String input, // Can be email or mobile
    String password,
    BuildContext context,
  ) async {
    try {
      String email = input;

      // Check if input is a mobile number (digits only, or starts with +)
      final isMobile = RegExp(r'^[0-9+]+$').hasMatch(input);

      if (isMobile) {
        // Query Firestore to find the email associated with this mobile
        final querySnapshot = await _firestore
            .collection('users')
            .where('mobile', isEqualTo: input)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No account found with this mobile number.',
          );
        }

        email = querySnapshot.docs.first['email'];
      }

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save FCM Token
      if (result.user != null) {
        await FcmService().setupToken(result.user!.uid);
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
      }
      return null;
    }
  }

  // ================= SIGN OUT =================
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ================= PASSWORD RESET =================
  Future<void> sendPasswordResetEmail(
    String input,
    BuildContext context,
  ) async {
    try {
      String email = input.trim();

      // Check if input is a mobile number
      final isMobile = RegExp(r'^[0-9+]+$').hasMatch(input);

      if (isMobile) {
        // Query Firestore to find the email associated with this mobile
        final querySnapshot = await _firestore
            .collection('users')
            .where('mobile', isEqualTo: input)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No account found with this mobile number.',
          );
        }

        email = querySnapshot.docs.first['email'];
      }

      await _auth.sendPasswordResetEmail(email: email);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to send reset email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
