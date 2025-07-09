import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _classNameController = TextEditingController();

  /// In‑memory schedule. Key = weekday; value = list of entries.
  final Map<String, List<_SchedEntry>> _schedule = {
    for (final d in _weekdays) d: <_SchedEntry>[],
  };

  Future<void> _createClass() async {
    final user = FirebaseAuth.instance.currentUser;
    final raw = _classNameController.text.trim();

    if (user == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter class name and login')),
      );
      return;
    }

    final now = DateTime.now();
    final monthYear = '${now.month.toString().padLeft(2, '0')}${now.year}';
    final safe = raw.replaceAll(' ', '_');
    final docId = '${user.email}-$safe-$monthYear';

    final docRef = FirebaseFirestore.instance.collection('classes').doc(docId);

    await docRef.set({
      'class_name': raw,
      'teacher_email': user.email,
      'created_at': Timestamp.now(),
    });

    final schedRef = docRef.collection('schedule');
    final batch = FirebaseFirestore.instance.batch();

    for (final day in _weekdays) {
      final list = _schedule[day]!;
      if (list.isEmpty) continue;

      batch.set(
        schedRef.doc(day),
        {
          'day': day,
          'entries': list
              .map((e) => {
            'subject': e.subject,
            'start': _fmt(context, e.start),
            'end': _fmt(context, e.end),
          })
              .toList(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Class and schedule saved')));
    Navigator.pop(context);
  }

  Future<void> _addEntry(String day) async {
    String? subject;
    TimeOfDay? start;
    TimeOfDay? end;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add $day class'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Subject'),
                onChanged: (v) => subject = v.trim(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked =
                        await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setStateDialog(() => start = picked);
                      },
                      child: Text(start == null ? 'Start' : start!.format(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked =
                        await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setStateDialog(() => end = picked);
                      },
                      child: Text(end == null ? 'End' : end!.format(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (subject != null && start != null && end != null) {
                setState(() => _schedule[day]!.add(_SchedEntry(subject!, start!, end!)));
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Class')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Class Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Weekly Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._weekdays.map(
                  (day) => Card(
                child: ExpansionTile(
                  title: Text(day),
                  children: [
                    if (_schedule[day]!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No classes yet'),
                      ),
                    ..._schedule[day]!.map(
                          (e) => ListTile(
                        title: Text(e.subject),
                        subtitle: Text('${_fmt(context, e.start)} – ${_fmt(context, e.end)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setState(() => _schedule[day]!.remove(e)),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add class'),
                        onPressed: () => _addEntry(day),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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

/* ────────── helpers ────────── */

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _fmt(BuildContext context, TimeOfDay t) => t.format(context);

class _SchedEntry {
  final String subject;
  final TimeOfDay start;
  final TimeOfDay end;
  _SchedEntry(this.subject, this.start, this.end);
}
