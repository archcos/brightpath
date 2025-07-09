import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'mainscreen/dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;

  Future<void> _updateUserData(User user) async {
    final now = DateTime.now();
    final docRef = _firestore.collection('users').doc(user.email);
    final snap   = await docRef.get();

    if (snap.exists) {
      final data = snap.data()!;
      await docRef.update({
        'name'        : user.displayName ?? data['name'] ?? '',
        'last_login'  : data['current_login'] ?? now.toIso8601String(),
        'current_login': now.toIso8601String(),
      });
    } else {
      await docRef.set({
        'name'        : user.displayName ?? user.email!.split('@')[0],
        'last_login'  : '',
        'current_login': now.toIso8601String(),
        'type'        : 'Parent',
        'status'      : 'Active',
        'created_date': now.toIso8601String(),
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);          // start spinner
    try {
      await _googleSignIn.signOut();
      final gUser = await _googleSignIn.signIn();
      if (gUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final docRef = _firestore.collection('users').doc(user.email);
      final snap = await docRef.get();

      if (snap.exists) {
        final status = snap.data()?['status'] ?? 'Active';
        if (status == 'Inactive') {
          await FirebaseAuth.instance.signOut();
          _showError(
              'Your account is inactive because you are no longer part of any class. Please contact your teacher or administrator.');
          setState(() => _isLoading = false);
          return;
        } else if (status == 'Suspended') {
          await FirebaseAuth.instance.signOut();
          _showError(
              'Your account has been suspended due to unusual activity. Please contact your teacher or administrator.');
          setState(() => _isLoading = false);
          return;
        }
      }

      await _updateUserData(user);

      final rawTime = snap.data()?['last_login'];
      final lastLog = rawTime == null || rawTime == ''
          ? 'First login'
          : DateFormat('MMMM d, y • h:mm:ss a')
          .format(DateTime.parse(rawTime));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${user.displayName}!\nLast login: $lastLog'),
          duration: const Duration(seconds: 4),
        ),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Google Sign‑In failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/header.png', width: 240, fit: BoxFit.contain),
                    const SizedBox(height: 32),
                    const Text(
                      'Sign in with your Google account to continue.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: Image.asset('assets/google.png', height: 24),
                        label: const Text(
                          'Sign in with Google',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.grey),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
