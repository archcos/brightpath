import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Not available';
    try {
      final date = DateTime.parse(raw);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null) {
      return const Scaffold(
        body: Center(child: Text('No logged in user')),
      );
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(email);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No profile data found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final lastLogin = formatDate(data['last_login']);
          final status = data['status'] ?? 'Unknown';
          final type = data['type'] ?? 'Unknown';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 10),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user!.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : const AssetImage('assets/defavatar.png') as ImageProvider,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user.email ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              ProfileTile(
                icon: Icons.login,
                title: 'Last Login',
                value: lastLogin,
              ),
              ProfileTile(
                icon: Icons.verified_user_outlined,
                title: 'Status',
                value: status,
              ),
              ProfileTile(
                icon: Icons.badge_outlined,
                title: 'User Type',
                value: type,
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }
}
