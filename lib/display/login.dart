import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'mainscreen/dashboard.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save or update user info in Firestore
  Future<void> _updateUserData(User user) async {
    final now = DateTime.now();

    final userRef = _firestore.collection('users').doc(user.email);

    final docSnapshot = await userRef.get();

    if (docSnapshot.exists) {
      // If user already exists, update last login and current login
      final data = docSnapshot.data()!;
      await userRef.update({
        'name': user.displayName ?? data['name'] ?? '',
        'last_login': data['current_login'] ?? now.toIso8601String(),
        'current_login': now.toIso8601String(),
      });
    } else {
      // If new user, create a new document
      await userRef.set({
        'name': user.displayName ?? user.email!.split('@')[0],
        'last_login': '',
        'current_login': now.toIso8601String(),
      });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _updateUserData(user);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${user.email}!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // Force account selection
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return; // Cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _updateUserData(user);

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();

        final rawTimestamp = doc.data()?['last_login'];
        String formattedTime = 'First login';

        if (rawTimestamp != null && rawTimestamp.toString().isNotEmpty) {
          final dt = DateTime.parse(rawTimestamp);
          formattedTime = DateFormat('MMMM d, y • h:mm:ss a').format(dt);
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Welcome, ${user.displayName}!\nLast login: $formattedTime'),
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signInWithEmail,
              child: const Text('Login with Email'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signInWithGoogle,
              child: const Text('Login with Google'),
            ),
          ],
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
