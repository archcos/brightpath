import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditClassScreen extends StatefulWidget {
  final String classId;
  const EditClassScreen({super.key, required this.classId});

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  final _name = TextEditingController();
  final Map<String, List<_Entry>> _sched = {
    for (final d in _days) d: <_Entry>[],
  };
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    _name.text = doc.get('class_name') ?? '';
    final snap = await doc.reference.collection('schedule').get();
    for (final d in snap.docs) {
      final data = d.data();
      if (data['entries'] is List) {
        for (final e in List<Map<String, dynamic>>.from(data['entries'])) {
          _sched[d.id]?.add(_Entry(e['subject'], _parse(e['start']), _parse(e['end'])));
        }
      } else {
        _sched[d.id]?.add(_Entry(data['subject'], _parse(data['start']), _parse(data['end'])));
      }
    }
    setState(() => loading = false);
  }

  Future<void> _pick(String day, [_Entry? entry]) async {
    String subj = entry?.subject ?? '';
    TimeOfDay? st = entry?.start;
    TimeOfDay? en = entry?.end;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(entry == null ? 'Add $day' : 'Edit $day'),
        content: StatefulBuilder(
          builder: (c, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: subj),
                decoration: const InputDecoration(labelText: 'Subject'),
                onChanged: (v) => subj = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: st ?? TimeOfDay.now());
                        if (t != null) setS(() => st = t);
                      },
                      child: Text(st == null ? 'Start' : st!.format(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: en ?? TimeOfDay.now());
                        if (t != null) setS(() => en = t);
                      },
                      child: Text(en == null ? 'End' : en!.format(context)),
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
              if (subj.isEmpty || st == null || en == null) return;
              setState(() {
                if (entry != null) _sched[day]!.remove(entry);
                _sched[day]!.add(_Entry(subj, st!, en!));
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final doc = FirebaseFirestore.instance.collection('classes').doc(widget.classId);
    await doc.update({'class_name': _name.text.trim()});
    final col = doc.collection('schedule');
    final batch = FirebaseFirestore.instance.batch();
    for (final d in _days) {
      final list = _sched[d]!;
      if (list.isEmpty) {
        batch.delete(col.doc(d));
      } else {
        batch.set(
          col.doc(d),
          {
            'day': d,
            'entries': list
                .map((e) => {'subject': e.subject, 'start': _fmt(e.start), 'end': _fmt(e.end)})
                .toList(),
          },
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Class')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Class Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ..._days.map((d) => Card(
            child: ExpansionTile(
              title: Text(d),
              children: [
                if (_sched[d]!.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No classes')),
                ..._sched[d]!.map(
                      (e) => ListTile(
                    title: Text(e.subject),
                    subtitle: Text('${e.start.format(context)} – ${e.end.format(context)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _pick(d, e)),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setState(() => _sched[d]!.remove(e)),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    onPressed: () => _pick(d),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  String _fmt(TimeOfDay t) => DateFormat.Hm().format(DateTime(0, 1, 1, t.hour, t.minute));
  TimeOfDay _parse(String s) {
    final dt = DateFormat.Hm().parse(s);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
}

class _Entry {
  final String subject;
  final TimeOfDay start;
  final TimeOfDay end;
  _Entry(this.subject, this.start, this.end);
}

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
