import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class InterventionScreen extends StatefulWidget {
  const InterventionScreen({super.key});

  @override
  State<InterventionScreen> createState() => _InterventionScreenState();
}

class _InterventionScreenState extends State<InterventionScreen> {
  final firestore = FirebaseFirestore.instance;
  final String geminiApiKey = 'AIzaSyBVZ7B5007uwy3HBlvjK4vOBC2kgK9-xD0';

  List<_Intervention> _interventions = [];
  bool _loading = true;
  final Map<int, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadInterventions();
  }

  String _base(String email) =>
      email.toLowerCase().replaceFirst(RegExp(r'\d+$'), '');

  Future<void> _loadInterventions() async {
    setState(() {
      _loading = true;
      _interventions = [];
    });

    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) throw Exception('Not signed in.');

      final studentsSnap = await firestore.collectionGroup('students').get();
      DocumentReference<Map<String, dynamic>>? classRef;

      for (final doc in studentsSnap.docs) {
        if (_base(doc.id) == _base(userEmail)) {
          classRef = doc.reference.parent.parent;
          break;
        }
      }
      if (classRef == null) throw Exception('Class not found.');

      final classId = classRef.id;
      final cols = ['assignments', 'quizzes', 'projects'];
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final fmt = DateFormat('yyyy-MM-dd');

      final List<_Intervention> out = [];

      for (final col in cols) {
        final snap = await firestore
            .collection('classes')
            .doc(classId)
            .collection(col)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final dueRaw = data['dueDate'] ?? '';
          if (dueRaw is! String || dueRaw.isEmpty) continue;

          final due = fmt.parse(dueRaw, true).toUtc();
          final diff = due.difference(now).inDays;
          if (diff < 0 || diff > 2) continue;

          final title = data['title'] ?? 'Untitled';
          final subject = data['subject'] ?? 'Unknown';
          final description = data['description'] ?? '';

          final suggestion =
          await _generateSuggestion(subject, title, description, dueRaw);

          out.add(_Intervention(
            title: title,
            subject: subject,
            description: description,
            dueDate: dueRaw,
            suggestion: suggestion,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _interventions = out;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<String> _generateSuggestion(
      String subject, String title, String desc, String dueDate) async {
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';

    final prompt =
        'You are a helpful academic coach. A student has a task due '
        'in 2 days.\n'
        'Subject: $subject\nTitle: $title\nDescription: $desc\nDue: $dueDate\n\n'
        'Give 2‑3 short, actionable steps the student can do today and tomorrow. '
        'Use bullet points. PLEASE Dont include  asterisks.';

    final res = await http.post(Uri.parse(endpoint),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }));

    if (res.statusCode != 200) {
      debugPrint('Gemini error → ${res.statusCode}: ${res.body}');
      return 'Could not fetch suggestion:\n${res.statusCode}';
    }

    final text = (jsonDecode(res.body)['candidates'][0]['content']['parts'][0]
    ['text'] as String)
        .trim();
    return text;
  }

  Future<void> _refresh() async {
    await _loadInterventions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interventions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: _interventions.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: Text('No upcoming tasks.'))
          ],
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _interventions.length,
          itemBuilder: (context, i) {
            final iv = _interventions[i];
            final isExpanded = _expanded[i] ?? false;

            return Card(
              color: Colors.indigo.shade800,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _expanded[i] = !(_expanded[i] ?? false);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iv.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(iv.description,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text('Subject: ${iv.subject}',
                          style: const TextStyle(color: Colors.white60)),
                      const SizedBox(height: 4),
                      Text('Due: ${iv.dueDate}',
                          style: const TextStyle(color: Colors.white60)),
                      const SizedBox(height: 8),
                      if (isExpanded)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(iv.suggestion,
                                style: const TextStyle(color: Colors.amber)),
                            const Text('Tap again to hide',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        )
                      else
                        const Text('Tap to see suggestion',
                            style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Intervention {
  final String title;
  final String subject;
  final String description;
  final String dueDate;
  final String suggestion;

  _Intervention({
    required this.title,
    required this.subject,
    required this.description,
    required this.dueDate,
    required this.suggestion,
  });
}
