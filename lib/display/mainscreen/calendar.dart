import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class _TaskView {
  final DateTime date;
  final String subject, title, description, type;
  _TaskView(this.date, this.subject, this.title, this.description, this.type);
}

class TaskEvent {
  final String type, subject, title, description;
  TaskEvent(this.type, this.subject, this.title, this.description);
}

String _base(String e) => e.toLowerCase().replaceFirst(RegExp(r'\d+$'), '');

Future<bool> _isTeacher(String email) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
  return doc.exists && (doc.data()?['type'] == 'Teacher');
}

Future<List<_TaskView>> _fetchTasks(String email) async {
  if (await _isTeacher(email)) {
    return _fetchTeacherTasks(email);
  } else {
    return _fetchStudentTasks(email);
  }
}

Future<List<_TaskView>> _fetchStudentTasks(String email) async {
  final base = _base(email);
  final snap = await FirebaseFirestore.instance.collectionGroup('students').get();
  final seen = <String>{};
  final out  = <_TaskView>[];

  for (final s in snap.docs) {
    if (_base(s.id) != base) continue;
    final cls = s.reference.parent.parent;
    if (cls == null || !seen.add(cls.id)) continue;

    for (final col in ['assignments', 'projects', 'quizzes']) {
      final ts = await cls.collection(col).get();
      for (final d in ts.docs) {
        final data = d.data();
        final due = DateTime.tryParse(data['dueDate'] ?? '');
        if (due == null) continue;

        final subject = data['subject'] ?? '';
        final type = _typeFromCollection(col);

        out.add(_TaskView(
          due,
          data['subject'] ?? '',
          data['title'] ?? '',
          data['description'] ?? '',
          type, // <-- now passes the correct type
        ));
      }
    }
  }
  return out;
}

Future<List<_TaskView>> _fetchTeacherTasks(String email) async {
  final prefix = '$email-';
  final snap   = await FirebaseFirestore.instance.collection('classes').get();
  final out    = <_TaskView>[];

  for (final c in snap.docs.where((d) => d.id.startsWith(prefix))) {
    final className = c.id.replaceFirst(prefix, '');
    for (final col in ['assignments', 'projects', 'quizzes']) {
      final ts = await c.reference.collection(col).get();
      for (final d in ts.docs) {
        final data = d.data();
        final due = DateTime.tryParse(data['dueDate'] ?? '');
        if (due == null) continue;

        final subject = data['subject'] ?? '';
        final type = _typeFromCollection(col);

        out.add(_TaskView(
          due,
          className.isEmpty ? subject : '$className – $subject',
          data['title'] ?? '',
          data['description'] ?? '',
          type,
        ));
      }
    }
  }
  return out;
}

String _typeFromCollection(String col) {
  switch (col) {
    case 'assignments': return 'Assignment';
    case 'projects': return 'Project';
    case 'quizzes': return 'Quiz';
    default: return 'Task';
  }
}

Map<DateTime, List<TaskEvent>> _eventsFrom(List<_TaskView> t) {
  final map = <DateTime, List<TaskEvent>>{};
  for (final item in t) {
    final key = DateTime.utc(item.date.year, item.date.month, item.date.day);
    map.putIfAbsent(key, () => []).add(
      TaskEvent(item.type, item.subject, item.title, item.description),
    );
  }
  return map;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _focused = DateTime.now();
  Map<DateTime, List<TaskEvent>> _events = {};
  bool _loading = true;
  final List<StreamSubscription> _subs = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      _loading = false;
      return;
    }

    _fetchTasks(email).then((tasks) async {
      if (!mounted) return;
      setState(() {
        _events = _eventsFrom(tasks);
        _loading = false;
      });
      await _attachLiveListeners(email);
    });
  }

  Future<void> _refresh() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    final tasks = await _fetchTasks(email);
    if (!mounted) return;
    setState(() => _events = _eventsFrom(tasks));
  }

  Future<void> _attachLiveListeners(String email) async {
    final base = _base(email);
    final snap = await FirebaseFirestore.instance.collectionGroup('students').get();
    final seen = <String>{};

    for (final s in snap.docs) {
      if (_base(s.id) != base) continue;
      final cls = s.reference.parent.parent;
      if (cls == null || !seen.add(cls.id)) continue;

      for (final col in ['assignments', 'projects', 'quizzes']) {
        final sub = cls.collection(col).snapshots().listen((_) async {
          final tasks = await _fetchTasks(email);
          if (mounted) {
            setState(() => _events = _eventsFrom(tasks));
          }
        });
        _subs.add(sub);
      }
    }
  }

  Color getEventColor(String type) {
    switch (type) {
      case 'Assignment':
        return Colors.red;
      case 'Quiz':
        return Colors.pink;
      case 'Project':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }


  List<TaskEvent> _eventsOf(DateTime day) =>
      _events[DateTime.utc(day.year, day.month, day.day)] ?? [];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Column(
              children: [
                TableCalendar<TaskEvent>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focused,
                  eventLoader: _eventsOf,
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders<TaskEvent>(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.take(3).map((e) {
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: getEventColor(e.type),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  onDaySelected: (sel, foc) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskDetailsPage(date: sel, events: _eventsOf(sel)),
                      ),
                    );
                    setState(() => _focused = foc);
                  },
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _LegendItem(color: Colors.red, label: 'Assignment'),
                      _LegendItem(color: Colors.pink, label: 'Quiz'),
                      _LegendItem(color: Colors.purple, label: 'Project'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}


class TaskDetailsPage extends StatelessWidget {
  const TaskDetailsPage({
    super.key,
    required this.date,
    required this.events,
  });

  final DateTime date;
  final List<TaskEvent> events;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('MMMM d, y').format(date))),
      body: events.isEmpty
          ? const Center(child: Text('No tasks for this date'))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: events.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child:  Text(e.type, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                Text('Title: ${e.title}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Section - Subject: ${e.subject}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Details: \n${e.description}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Deadline: ${DateFormat('MMMM d, y').format(date)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    e.type == 'Assignment'
                        ? Icons.assignment
                        : e.type == 'Quiz'
                        ? Icons.quiz
                        : Icons.build_circle,
                    color: e.type == 'Assignment'
                        ? Colors.red
                        : e.type == 'Quiz'
                        ? Colors.pink
                        : Colors.purple,
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
