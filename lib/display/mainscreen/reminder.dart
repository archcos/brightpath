import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TaskItem {
  final DateTime due;
  final String subject, title, description;

  _TaskItem(this.due, this.subject, this.title, this.description);

  String get id => '$title|${due.toIso8601String()}';
}

String _base(String e) => e.toLowerCase().replaceFirst(RegExp(r'\d+$'), '');

Future<List<_TaskItem>> fetchTasks(String email) async {
  final base = _base(email);
  final snap = await FirebaseFirestore.instance.collectionGroup('students').get();
  final seen = <String>{};
  final out = <_TaskItem>[];

  for (final s in snap.docs) {
    if (_base(s.id) != base) continue;
    final cls = s.reference.parent.parent;
    if (cls == null || !seen.add(cls.id)) continue;

    for (final col in ['assignments', 'projects', 'quizzes']) {
      final ts = await cls.collection(col).get();
      for (final d in ts.docs) {
        final data = d.data();
        final dd = data['dueDate'];
        if (dd is! String) continue;
        final date = DateTime.tryParse(dd);
        if (date == null) continue;
        out.add(_TaskItem(
          date,
          data['subject'] ?? '',
          data['title'] ?? '',
          data['description'] ?? '',
        ));
      }
    }
  }

  out.sort((a, b) => a.due.compareTo(b.due));
  return out;
}

enum TaskView { pending, completed }

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, required this.pendingNotifier});
  final ValueNotifier<int> pendingNotifier;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<_TaskItem> _tasks = [];
  Set<String> _completedIds = {};
  TaskView _view = TaskView.pending;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _updatePendingCount() {
    if (!mounted) return;
    final pending = _tasks.where((t) => !_completedIds.contains(t.id)).length;
    widget.pendingNotifier.value = pending;
  }


  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _completedIds = prefs.getStringList('completedTasks')?.toSet() ?? {};
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      final fetched = await fetchTasks(email);
      setState(() {
        _tasks = fetched;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
    _updatePendingCount();
  }

  Future<void> _toggleComplete(_TaskItem task, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (value) {
        _completedIds.add(task.id);
      } else {
        _completedIds.remove(task.id);
      }
    });
    await prefs.setStringList('completedTasks', _completedIds.toList());
    _updatePendingCount();
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount =
        _tasks.where((t) => !_completedIds.contains(t.id)).length;
    final int completedCount =
        _tasks.where((t) => _completedIds.contains(t.id)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<TaskView>(
              value: _view,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: TaskView.pending,
                  child: Text('Pending ($pendingCount)'),
                ),
                DropdownMenuItem(
                  value: TaskView.completed,
                  child: Text('Completed ($completedCount)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _view = val);
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, i) {
                  final t = _tasks[i];
                  final isCompleted = _completedIds.contains(t.id);
                  final shouldShow =
                      (_view == TaskView.completed && isCompleted) ||
                          (_view == TaskView.pending && !isCompleted);
                  if (!shouldShow) return const SizedBox.shrink();

                  final dueStr =
                  DateFormat('yMMMd – h:mm a').format(t.due);
                  return Card(
                    color: isCompleted
                        ? Colors.green.shade700
                        : Colors.indigo.shade800,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.subject,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          Checkbox(
                            value: isCompleted,
                            onChanged: (val) {
                              if (val != null) _toggleComplete(t, val);
                            },
                            activeColor: Colors.white,
                            checkColor: Colors.indigo,
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(t.title,
                              style:
                              const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(t.description,
                              style:
                              const TextStyle(color: Colors.white60)),
                          const SizedBox(height: 4),
                          Text('Due: $dueStr',
                              style:
                              const TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
