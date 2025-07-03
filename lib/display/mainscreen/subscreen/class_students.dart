import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClassStudentsPage extends StatelessWidget {
  final String classId;
  final String className;

  const ClassStudentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  Future<void> _deleteClass(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Class'),
          content: Text('Are you sure you want to delete "$className"? '
              'This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Delete the class document. Sub‑collections are not removed automatically.
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .delete();

        // Optional: show feedback before leaving the page.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class deleted')),
          );
        }

        // Close this page.
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete class: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsRef = FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('students');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Students of $className',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete class',
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteClass(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: studentsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data!.docs;

          if (students.isEmpty) {
            return const Center(child: Text('No students enrolled.'));
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student =
              students[index].data() as Map<String, dynamic>;

              final fullName = [
                student['first_name'],
                student['last_name'],
              ]
                  .where((part) =>
              part != null && part.toString().trim().isNotEmpty)
                  .join(' ');

              return ListTile(
                title: Text(fullName.isNotEmpty ? fullName : 'Unnamed'),
                subtitle:
                Text(student['parent_email'] ?? 'No parent email'),
              );
            },
          );
        },
      ),
    );
  }
}
