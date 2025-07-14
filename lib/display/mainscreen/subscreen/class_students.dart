import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../sidebar/add_student.dart';
import 'edit_class.dart';
import 'edit_class_item.dart';

class ClassStudentsPage extends StatelessWidget {
  const ClassStudentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  final String classId;
  final String className;

  /// Helper to reach a sub‑collection of the class
  CollectionReference<Map<String, dynamic>> _subCol(String name) =>
      FirebaseFirestore.instance.collection('classes').doc(classId).collection(name);

  /// Ask and delete the whole class (unchanged)
  Future<void> _deleteClass(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Delete "$className" and everything inside it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('classes').doc(classId).delete();
      if (context.mounted) Navigator.pop(context);
    }
  }

  /// Ask and delete a single document inside a sub‑collection
  Future<void> _deleteItem(
      BuildContext context, {
        required String collectionName,
        required String docId,
        required String headline,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Delete "$headline"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _subCol(collectionName).doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class: $className', style: const TextStyle(fontSize: 16)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EditClassScreen(classId: classId),
                ));
              } else if (v == 'delete') {
                _deleteClass(context);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit class')),
              PopupMenuItem(value: 'delete', child: Text('Delete class')),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          _studentsTile(context),
          _taskTile(
            context,
            title: 'Summaries',
            collection: 'summaries',
            icon: Icons.summarize,
            iconColor: Colors.green,
            fields: const ['subject', 'topic', 'summary'],
          ),
          _taskTile(
            context,
            title: 'Assignments',
            collection: 'assignments',
            icon: Icons.assignment,
            iconColor: Colors.red,
            fields: const ['subject', 'title', 'description', 'dueDate'],
          ),
          _taskTile(
            context,
            title: 'Projects',
            collection: 'projects',
            icon: Icons.build_circle,
            iconColor: Colors.purple,
            fields: const ['subject', 'title', 'description', 'dueDate'],
          ),
          _taskTile(
            context,
            title: 'Quizzes',
            collection: 'quizzes',
            icon: Icons.quiz,
            iconColor: Colors.pink,
            fields: const ['subject', 'title', 'description', 'dueDate'],
          ),
        ],
      ),
    );
  }

  /// Students panel
  Widget _studentsTile(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      title: const Text('Students'),
      leading: const Icon(Icons.group),
      children: [
        ListTile(
          leading: const Icon(Icons.person_add),
          title: const Text('Add student'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddStudentToClassScreen(),
              ),
            );
          },
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _subCol('students').snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const CircularProgressIndicator();
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const ListTile(title: Text('No students yet.'));
            }
            return Column(
              children: docs.map((d) {
                final m = d.data() as Map<String, dynamic>;
                final name =
                '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                return ListTile(
                  title: Text(name.isEmpty ? 'Unnamed' : name),
                  subtitle: Text(m['parent_email'] ?? ''),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }


  /// Generic panel for summaries / assignments / projects / quizzes
  Widget _taskTile(
      BuildContext context, {
        required String title,
        required String collection,
        required IconData icon,
        required Color iconColor,
        required List<String> fields,
      }) {
    final query = collection == 'summaries'
        ? _subCol(collection)                       // no ordering for summaries
        : _subCol(collection).orderBy('dueDate');   // keep order for others

    return ExpansionTile(
      initiallyExpanded: false,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Add $title'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditTaskScreen(
                  classId: classId,
                  collectionName: collection,
                  fields: fields,
                ),
              ),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const CircularProgressIndicator();

            final docs = snap.data!.docs;
            debugPrint('[$collection] fetched docs: ${docs.length}');

            if (docs.isEmpty) return ListTile(title: Text('No $title yet.'));

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final subtitle = fields
                    .skip(1)
                    .map((f) => data[f]?.toString())
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' • ');

                return Column(
                  children: [
                    ListTile(
                      title: Text(data[fields.first] ?? ''),
                      subtitle: Text(subtitle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditTaskScreen(
                                  classId: classId,
                                  collectionName: collection,
                                  fields: fields,
                                  documentId: doc.id,
                                  existingData: data,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteItem(
                              context,
                              collectionName: collection,
                              docId: doc.id,
                              headline: data[fields.first] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
