import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'subscreen/class_students.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? userEmail;

  final List<Color> _iconColors = [
    Colors.indigo,
    Colors.deepOrange,
    Colors.teal,
    Colors.purple,
    Colors.blueGrey,
    Colors.green,
    Colors.red,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    userEmail = _auth.currentUser?.email;
    if (userEmail != null) _ensureFolder(userEmail!);
  }

  Future<void> _ensureFolder(String email) async {
    final client = sb.Supabase.instance.client;
    final prefix = '$email/';
    final list = await client.storage
        .from('audio')
        .list(path: prefix, searchOptions: const sb.SearchOptions(limit: 1));
    if (list.isEmpty) {
      await client.storage.from('audio').uploadBinary(
        '$prefix.keep',
        Uint8List(0),
        fileOptions: const sb.FileOptions(upsert: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userEmail == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Student',
        heroTag: 'addStudentBn',
        onPressed: () => Navigator.pushNamed(context, '/student'),
        child: const Icon(Icons.group_add_rounded),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('classes').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final classDocs = snapshot.data!.docs
              .where((doc) => doc.id.startsWith(userEmail!))
              .toList();

          if (classDocs.isEmpty) {
            return const Center(child: Text('No classes found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: classDocs.length,
            itemBuilder: (context, index) {
              final classId = classDocs[index].id;
              final displayName = classId.replaceFirst('$userEmail-', '');
              final iconColor = _iconColors[index % _iconColors.length];

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.2),
                    child: Icon(Icons.class_, color: iconColor),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassStudentsPage(
                        classId: classId,
                        className: displayName,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
