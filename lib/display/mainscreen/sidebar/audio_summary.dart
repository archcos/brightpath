import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'task_extract.dart';

class AudioSummaryPage extends StatefulWidget {
  const AudioSummaryPage({super.key});
  @override
  State<AudioSummaryPage> createState() => _AudioSummaryPageState();
}

class _AudioSummaryPageState extends State<AudioSummaryPage> {
  final supabase = Supabase.instance.client;
  final firestore = FirebaseFirestore.instance;

  final assemblyApiKey = 'fc605982a2944a37a7d40838c728eeb3';
  final geminiApiKey = 'AIzaSyBVZ7B5007uwy3HBlvjK4vOBC2kgK9-xD0';

  final String bucket = 'audio';
  String prefix = '';

  String? _teacherEmail;
  String? _classId;

  /// All files found under `bucket/prefix`
  List<String> _allFiles = [];

  /// Files that match the currently selected date
  List<String> _filesForDate = [];

  bool loadingTeacher = true;
  bool loadingList = true;
  bool processing = false;

  /// Date shown in the header; defaults to “today” (PH time)
  DateTime _selectedDate =
  DateTime.now().toUtc().add(const Duration(hours: 8));

  @override
  void initState() {
    super.initState();
    _initForUser();
  }

  String _base(String email) =>
      email.toLowerCase().replaceFirst(RegExp(r'\d+$'), '');

  /* ───────────────── Teacher / class lookup ───────────────── */

  Future<void> _initForUser() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    if (userEmail == null) {
      _showError('Not signed in.');
      return;
    }

    try {
      final studentsSnap = await firestore.collectionGroup('students').get();
      final baseUser = _base(userEmail);

      DocumentReference<Map<String, dynamic>>? classRef;

      for (final doc in studentsSnap.docs) {
        if (_base(doc.id) == baseUser) {
          classRef = doc.reference.parent.parent;
          break;
        }
      }

      if (classRef == null) {
        _showError('Class not found for $userEmail');
        setState(() => loadingTeacher = false);
        return;
      }

      final classDoc = await classRef.get();
      final teacherEmail = classDoc.data()?['teacher_email'] as String?;
      if (teacherEmail == null || teacherEmail.isEmpty) {
        _showError('Teacher email missing in class.');
        setState(() => loadingTeacher = false);
        return;
      }

      setState(() {
        _teacherEmail = teacherEmail;
        _classId = classRef!.id;
        prefix = teacherEmail; // storage path is audio/{teacherEmail}
        loadingTeacher = false;
      });

      _fetchAudioFiles();
    } catch (e) {
      _showError('Lookup failed: $e');
      setState(() => loadingTeacher = false);
    }
  }

  /* ───────────────── Supabase list & filter ───────────────── */

  Future<void> _fetchAudioFiles() async {
    if (prefix.isEmpty) return;
    try {
      final objects = await supabase.storage.from(bucket).list(path: prefix);
      _allFiles = objects.map((o) => o.name).toList();
      loadingList = false;
      _applyDateFilter();
    } catch (e) {
      _showError('Could not fetch audio files: $e');
      setState(() => loadingList = false);
    }
  }

  void _applyDateFilter() {
    final dateStr = DateFormat('yyyyMMdd').format(_selectedDate);
    setState(() {
      _filesForDate = _allFiles.where((f) => f.startsWith(dateStr)).toList();
    });
  }

  void _changeDate(int offsetDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    _applyDateFilter();
  }

  /* ───────────────── Helpers ───────────────── */

  String _publicUrlFor(String fileName) {
    final fullPath = '$prefix/$fileName';
    final url = supabase.storage.from(bucket).getPublicUrl(fullPath);
    if (url.isEmpty) throw Exception('Public URL for $fullPath is empty');
    return url;
  }

  Future<String> _transcribe(String audioUrl) async {
    final response = await http.post(
      Uri.parse('https://api.assemblyai.com/v2/transcript'),
      headers: {
        'authorization': assemblyApiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({'audio_url': audioUrl}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to start transcription: ${response.body}');
    }

    final id = jsonDecode(response.body)['id'];

    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      final statusRes = await http.get(
        Uri.parse('https://api.assemblyai.com/v2/transcript/$id'),
        headers: {'authorization': assemblyApiKey},
      );
      final data = jsonDecode(statusRes.body);
      if (data['status'] == 'completed') return data['text'];
      if (data['status'] == 'error') {
        throw Exception('Transcription failed: ${data['error']}');
      }
    }
  }

  Future<Map<String, String>> _summarise(String transcript) async {
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                'Summarize this transcription without explaining that it is a transcription. '
                    'Just summarize everything that was talked about. If there is mention of Assignment, Quiz, or any other thing with a date, format as bullet like: Assignment, Deadline: July 7, 2025. '
                    'Put the EXACT DATE by comparing the date of processing and the upload date of the file. '
                    'Lastly, categorize the topic in the summary, if it talks about Science, Math, English, Filipino etc., make it the Subject. '
                    'Then also give the specific Topic like "Addition" or "Photosynthesis" and as short as possible. Format it at the end like:\n'
                    'Subject: Science\nTopic: Photosynthesis\n\n$transcript'
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error: ${response.body}');
    }

    final text = (jsonDecode(response.body)['candidates'][0]['content']['parts']
    [0]['text'] as String)
        .trim();

    final subjectRegex = RegExp(r'Subject:\s*(.+)', caseSensitive: false);
    final topicRegex = RegExp(r'Topic:\s*(.+)', caseSensitive: false);

    final subjectMatch = subjectRegex.firstMatch(text);
    final topicMatch = topicRegex.firstMatch(text);

    final subject =
    subjectMatch != null ? subjectMatch.group(1)?.trim() ?? 'Unknown' : 'Unknown';
    final topic =
    topicMatch != null ? topicMatch.group(1)?.trim() ?? 'Unknown' : 'Unknown';

    final cleanedSummary = text
        .replaceAll(subjectMatch?.group(0) ?? '', '')
        .replaceAll(topicMatch?.group(0) ?? '', '')
        .trim();

    return {
      'summary': cleanedSummary,
      'subject': subject,
      'topic': topic,
    };
  }

  Future<void> _process(String fileName) async {
    if (_classId == null) return;
    setState(() => processing = true);

    try {
      final docRef = firestore
          .collection('classes')
          .doc(_classId)
          .collection('summaries')
          .doc(fileName);

      final doc = await docRef.get();

      String summary, subject = 'Unknown', topic = 'Unknown';

      if (doc.exists) {
        summary = doc['summary'];
        subject = doc['subject'] ?? 'Unknown';
        topic = doc['topic'] ?? 'Unknown';
      } else {
        final audioUrl = _publicUrlFor(fileName);
        final transcript = await _transcribe(audioUrl);
        final result = await _summarise(transcript);

        summary = result['summary'] ?? '';
        subject = result['subject'] ?? 'Unknown';
        topic = result['topic'] ?? 'Unknown';

        await docRef.set({
          'transcript': transcript,
          'summary': summary,
          'subject': subject,
          'topic': topic,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      final extractor = TaskExtractor(firestore, geminiApiKey);
      await extractor.run(classId: _classId!, summary: summary, subject: subject);
      _showSummaryDialog(fileName, summary, subject, topic);
    } catch (e) {
      _showError('Processing failed: $e');
    } finally {
      setState(() => processing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSummaryDialog(
      String file, String summary, String subject, String topic) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Summary – $file'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary),
              const SizedBox(height: 16),
              Text('Subject: $subject',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Topic: $topic',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  /* ───────────────── UI ───────────────── */

  @override
  Widget build(BuildContext context) {
    final isLoading = loadingTeacher || loadingList;

    return Scaffold(
      appBar: AppBar(title: const Text('Audio‑to‑Summary')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : processing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async => _fetchAudioFiles(),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () => _changeDate(-1),
                    child: const Text('<')),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, y').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                TextButton(
                    onPressed: () => _changeDate(1),
                    child: const Text('>')),
              ],
            ),
            const Divider(height: 0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Reminder: Always check the Calendar tab for quizzes, assignments, and projects updates.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.orange),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _filesForDate.isEmpty
                        ? const Center(child: Text('No audio files for this date.'))
                        : ListView.builder(
                      itemCount: _filesForDate.length,
                      itemBuilder: (_, i) {
                        final file = _filesForDate[i];
                        return ListTile(
                          leading: const Icon(Icons.audiotrack),
                          title: Text(file),
                          onTap: () => _process(file),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
