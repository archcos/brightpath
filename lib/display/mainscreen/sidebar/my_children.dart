import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../subscreen/add_child.dart';
import '../subscreen/edit_child.dart';

class MyChildrenPage extends StatefulWidget {
  const MyChildrenPage({super.key});

  @override
  State<MyChildrenPage> createState() => _MyChildrenPageState();
}

class _MyChildrenPageState extends State<MyChildrenPage> {
  String? _parentEmail;

  @override
  void initState() {
    super.initState();
    _parentEmail = FirebaseAuth.instance.currentUser?.email;
  }

  Future<List<Map<String, dynamic>>> _fetchChildren() async {
    if (_parentEmail == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_parentEmail)
        .collection('children')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'first_name': data['first_name'] ?? '',
        'middle_name': data['middle_name'] ?? '',
        'last_name': data['last_name'] ?? '',
        'suffix': data['suffix'] ?? '',
        'age': data['age'] ?? '',
        'gender': data['gender'] ?? '',
      };
    }).toList();
  }

  void _editChild(Map<String, dynamic> childData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditChildScreen(childData: childData),
      ),
    ).then((_) => setState(() {}));
  }

  void _addChild() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Children')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = snapshot.data ?? [];

          if (children.isEmpty) {
            return const Center(child: Text('No children registered.'));
          }

          return ListView.builder(
            itemCount: children.length,
            itemBuilder: (_, index) {
              final child = children[index];
              final fullName =
              '${child['first_name']} ${child['middle_name']} ${child['last_name']} ${child['suffix']}'.trim();

              return ListTile(
                title: Text(fullName),
                subtitle: Text('Age: ${child['age']} | Gender: ${child['gender']}'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editChild(child),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChild,
        icon: const Icon(Icons.add),
        label: const Text('Add Child'),
      ),
    );
  }
}
