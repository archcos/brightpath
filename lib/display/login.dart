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

  /* ───────────────── Firestore helper ───────────────── */
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

  /* ───────────────── Google sign‑in ─────────────────── */
  Future<void> _signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();               // always prompt
      final gUser = await _googleSignIn.signIn();
      if (gUser == null) return;                   // cancelled

      final gAuth     = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken    : gAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user     = userCred.user;
      if (user == null) return;

      await _updateUserData(user);

      /* last‑login snack */
      final doc     = await _firestore.collection('users').doc(user.email).get();
      final rawTime = doc.data()?['last_login'];
      final lastLog = rawTime == null || rawTime == ''
          ? 'First login'
          : DateFormat('MMMM d, y • h:mm:ss a').format(DateTime.parse(rawTime));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content : Text('Welcome, ${user.displayName}!\nLast login: $lastLog'),
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign‑In failed: $e')),
      );
    }
  }

  /* ───────────────── UI ─────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /* header banner */
                Image.asset(
                  'assets/header.png',
                  width: 240,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),

                /* instructions */
                const Text(
                  'Sign in with your Google account to continue.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                /* Google sign‑in button */
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Image.asset(
                      'assets/google.png',
                      height: 24,
                    ),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side   : const BorderSide(color: Colors.grey),
                      backgroundColor: Colors.white,
                    ),
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
