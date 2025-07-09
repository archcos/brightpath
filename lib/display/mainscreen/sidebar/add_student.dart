import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../subscreen/create_class.dart';

class AddStudentToClassScreen extends StatefulWidget {
  const AddStudentToClassScreen({super.key});

  @override
  State<AddStudentToClassScreen> createState() =>
      _AddStudentToClassScreenState();
}

class _AddStudentToClassScreenState extends State<AddStudentToClassScreen> {
  List<Map<String, dynamic>> availableStudents = [];
  Set<String> selectedStudentIds = {};
  List<DocumentSnapshot> classList = [];
  String? selectedClassId;
  String? selectedClassLabel;
  String studentSearchQuery = '';
  late final String? currentUserEmail;

  @override
  void initState() {
    super.initState();
    currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    _fetchClasses();
    _loadEligibleChildren();
  }

  Future<void> _fetchClasses() async {
    if (currentUserEmail == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacher_email', isEqualTo: currentUserEmail)
        .get();
    final docs = snap.docs
        .where((doc) => doc.id.startsWith('$currentUserEmail-'))
        .toList();
    setState(() => classList = docs);
  }

  Future<void> _loadEligibleChildren() async {
    final usersSnap =
    await FirebaseFirestore.instance.collection('users').get();
    final List<Map<String, dynamic>> children = [];
    for (var userDoc in usersSnap.docs) {
      if (userDoc.data()['type'] == 'Parent') {
        final kidsSnap = await userDoc.reference.collection('children').get();
        for (var kid in kidsSnap.docs) {
          final data = kid.data();
          children.add({
            'id': kid.id,
            'first_name': data['first_name'] ?? '',
            'last_name': data['last_name'] ?? '',
            'parent_email': userDoc.id,
          });
        }
      }
    }
    setState(() => availableStudents = children);
  }

  Future<void> _loadStudentsInClass(String classId) async {
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('students')
        .get();
    final emails = snap.docs
        .map((d) => d.get('parent_email') as String? ?? '')
        .toSet();
    final ids = availableStudents
        .where((s) => emails.contains(s['parent_email']))
        .map((s) => s['id'] as String)
        .toSet();
    setState(() => selectedStudentIds = ids);
  }

  String _uniqueId(String email, Set<String> existing) {
    var id = email;
    var i = 1;
    while (existing.contains(id)) {
      id = '$email$i';
      i++;
    }
    existing.add(id);
    return id;
  }

  Future<void> _updateClassStudents() async {
    if (selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class first')),
      );
      return;
    }
    final studentsRef = FirebaseFirestore.instance
        .collection('classes')
        .doc(selectedClassId)
        .collection('students');
    final existingSnap = await studentsRef.get();
    final batch = FirebaseFirestore.instance.batch();
    final existingIds = existingSnap.docs.map((d) => d.id).toSet();
    for (var doc in existingSnap.docs) {
      final base = doc.id.replaceFirst(RegExp(r'\d+$'), '');
      final keep = availableStudents.any((s) =>
      selectedStudentIds.contains(s['id']) &&
          s['parent_email'] == base);
      if (!keep) batch.delete(doc.reference);
    }
    final usedIds = existingIds.toSet();
    for (var s in availableStudents) {
      if (!selectedStudentIds.contains(s['id'])) continue;
      final email = s['parent_email'] as String;
      final docId = _uniqueId(email, usedIds);
      batch.set(studentsRef.doc(docId), {
        'first_name': s['first_name'],
        'last_name': s['last_name'],
        'parent_email': email,
      });
    }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class updated successfully')),
    );
  }

  void _showClassPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: classList.map((doc) {
          final label = doc.id.replaceFirst('${currentUserEmail!}-', '');
          return ListTile(
            title: Text(label),
            onTap: () async {
              Navigator.pop(ctx);
              setState(() {
                selectedClassId = doc.id;
                selectedClassLabel = label;
              });
              await _loadStudentsInClass(doc.id);
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = availableStudents.where((student) {
      final fullName =
      '${student['first_name']} ${student['last_name']}'.toLowerCase();
      return fullName.contains(studentSearchQuery.toLowerCase());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Add / Remove Students')),
      body: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateClassScreen()),
              );
              await _fetchClasses();
            },
            icon: const Icon(Icons.add),
            label: const Text('Create New Class'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              readOnly: true,
              controller: TextEditingController(text: selectedClassLabel),
              decoration: const InputDecoration(
                labelText: 'Class',
                suffixIcon: Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(),
              ),
              onTap: _showClassPicker,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search student by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => studentSearchQuery = value);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredStudents.isEmpty
                ? const Center(child: Text('No matching students'))
                : ListView.builder(
              itemCount: filteredStudents.length,
              itemBuilder: (_, i) {
                final s = filteredStudents[i];
                final full = '${s['first_name']} ${s['last_name']}';
                return CheckboxListTile(
                  title: Text(full),
                  subtitle: Text('Parent: ${s['parent_email']}'),
                  value: selectedStudentIds.contains(s['id']),
                  onChanged: (checked) => setState(() {
                    checked == true
                        ? selectedStudentIds.add(s['id'])
                        : selectedStudentIds.remove(s['id']);
                  }),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _updateClassStudents,
        icon: const Icon(Icons.save),
        label: const Text('Save Changes'),
      ),
    );
  }
}
