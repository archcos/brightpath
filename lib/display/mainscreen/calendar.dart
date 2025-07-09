// calendar_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Internal model for a task document.
class _TaskView {
  final DateTime date;
  final String subject, title, description;
  _TaskView(this.date, this.subject, this.title, this.description);
}

/// Event used by TableCalendar.
class TaskEvent {
  final String subject, title, description;
  TaskEvent(this.subject, this.title, this.description);
}

/// Helper that strips trailing digits from an email‐based document ID.
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
        final due  = DateTime.tryParse(data['dueDate'] ?? '');
        if (due == null) continue;
        out.add(_TaskView(
          due,
          data['subject'] ?? '',
          data['title'] ?? '',
          data['description'] ?? '',
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
    final className = c.id.replaceFirst(prefix, '');   // e.g. “Math101”
    for (final col in ['assignments', 'projects', 'quizzes']) {
      final ts = await c.reference.collection(col).get();
      for (final d in ts.docs) {
        final data = d.data();
        final due  = DateTime.tryParse(data['dueDate'] ?? '');
        if (due == null) continue;

        final subject = data['subject'] ?? '';
        // put class name in front: “Math101 – Algebra”
        out.add(_TaskView(
          due,
          className.isEmpty ? subject : '$className – $subject',
          data['title'] ?? '',
          data['description'] ?? '',
        ));
      }
    }
  }
  return out;
}


/// Converts the task list into the structure TableCalendar expects.
Map<DateTime, List<TaskEvent>> _eventsFrom(List<_TaskView> t) {
  final map = <DateTime, List<TaskEvent>>{};
  for (final item in t) {
    final key = DateTime.utc(item.date.year, item.date.month, item.date.day);
    map.putIfAbsent(key, () => []).add(
      TaskEvent(item.subject, item.title, item.description),
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

  final List<StreamSubscription> _subs = []; // keep track of live listeners

  @override
  bool get wantKeepAlive => true; // keep state when switching tabs

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      _loading = false;
      return;
    }

    // One‑time pull, then attach listeners.
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


  /// Sets up a snapshots() listener for every relevant sub‑collection.
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

  List<TaskEvent> _eventsOf(DateTime day) =>
      _events[DateTime.utc(day.year, day.month, day.day)] ?? [];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel(); // clean up listeners
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
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
            TableCalendar<TaskEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focused,
              eventLoader: _eventsOf,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
          ],
        ),
      ),
    );
  }
}

/// Shows all events for the selected day.
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
        children: events.map((e) {
          return ListTile(
            leading: const Icon(Icons.assignment),
            title: Text(e.subject),
            subtitle: Text('${e.title}\n${e.description}'),
          );
        }).toList(),
      ),
    );
  }
}
