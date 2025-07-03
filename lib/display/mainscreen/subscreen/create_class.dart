import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final TextEditingController _classNameController = TextEditingController();

  Future<void> _createClass() async {
    final classNameRaw = _classNameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (classNameRaw.isEmpty || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter class name and login')),
      );
      return;
    }

    // Format: email-classname-monthyear
    final now = DateTime.now();
    final monthYear = '${now.month.toString().padLeft(2, '0')}${now.year}';

    final safeClassName = classNameRaw.replaceAll(' ', '_'); // Optional
    final docId = '${user.email}-$safeClassName-$monthYear';

    final docRef = FirebaseFirestore.instance.collection('classes').doc(docId);

    await docRef.set({
      'class_name': classNameRaw,
      'teacher_email': user.email,
      'created_at': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class created successfully')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Class')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Class Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _createClass,
              icon: const Icon(Icons.check),
              label: const Text('Save Class'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }
}
