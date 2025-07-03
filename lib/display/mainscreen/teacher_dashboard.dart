import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    userEmail = _auth.currentUser?.email;
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
        title: const Text('Teacher Dashboard'),
      ),

      // Floating Action Button to open /student
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Student',
        heroTag: 'addStudentBtn',
        onPressed: () {
          Navigator.pushNamed(context, '/student');
        },
        child: const Icon(Icons.group_add_rounded),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('classes').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final classDocs = snapshot.data!.docs.where((doc) {
            return doc.id.startsWith(userEmail!);
          }).toList();

          if (classDocs.isEmpty) {
            return const Center(child: Text('No classes found.'));
          }

          return ListView.builder(
            itemCount: classDocs.length,
            itemBuilder: (context, index) {
              final classId = classDocs[index].id;
              final displayName = classId.replaceFirst('$userEmail-', '');

              return ListTile(
                title: Text(displayName),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassStudentsPage(
                        classId: classId,
                        className: displayName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
