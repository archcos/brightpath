import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TaskExtractor {
  TaskExtractor(this._firestore, this._geminiKey);

  final FirebaseFirestore _firestore;
  final String _geminiKey;

  static const Map<String, String> _collectionFor = {
    'assignment': 'assignments',
    'quiz': 'quizzes',
    'lesson': 'lessons',
    'project': 'projects',
  };

  Future<void> run({
    required String classId,
    required String summary,
    String? subject,
  }) async {
    debugPrint('TaskExtractor: summary received (${summary.length} chars)');
    final tasksJson = await _extractTasksWithGemini(summary);
    debugPrint('TaskExtractor: Gemini raw JSON -> $tasksJson');
    final List<dynamic> tasks;
    try {
      tasks = jsonDecode(tasksJson) as List<dynamic>;
    } on FormatException {
      debugPrint('TaskExtractor: JSON decode failed');
      return;
    }
    debugPrint('TaskExtractor: parsed ${tasks.length} tasks');
    final writeBatch = _firestore.batch();
    int assignmentsCount = 0;
    for (final raw in tasks) {
      if (raw is! Map) continue;
      final type = (raw['type'] as String? ?? 'other').toLowerCase().trim();
      if (type == 'assignment') assignmentsCount++;
      final colName = _collectionFor[type] ?? 'other_tasks';
      final subj = (subject ?? 'unknown').toLowerCase().replaceAll(' ', '');
      DateTime dt;
      try {
        dt = DateTime.parse(raw['dueDate'] ?? '');
      } catch (_) {
        dt = DateTime.now();
      }
      final datePart =
          '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}-${dt.year}';
      final docId = '$subj-$datePart';
      final docRef = _firestore
          .collection('classes')
          .doc(classId)
          .collection(colName)
          .doc(docId);
      writeBatch.set(docRef, {
        'title': raw['title'] ?? '',
        'description': raw['description'] ?? '',
        'dueDate': raw['dueDate'] ?? '',
        'subject': subject ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'raw': raw,
      });
    }
    debugPrint('TaskExtractor: assignments extracted $assignmentsCount');
    await writeBatch.commit();
    debugPrint('TaskExtractor: writeBatch committed');
  }

  Future<String> _extractTasksWithGemini(String summary) async {
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey';
    final prompt = '''
From the text below, list every Assignment, Quiz, Project or Lesson that has a due date (or any explicit date). Return ONLY a JSON array. Each element must have these fields exactly:

  {
    "type": "assignment" | "quiz" | "lesson" | "project" | "other",
    "title": "short title",
    "description": "extra details (may be empty)",
    "dueDate": "YYYY-MM-DD"
  }

Text:
$summary
''';
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Gemini error: ${res.body}');
    }
    final text =
    (jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text']
    as String)
        .trim();
    final jsonStart = text.indexOf('[');
    final jsonEnd = text.lastIndexOf(']');
    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
      return '[]';
    }
    return text.substring(jsonStart, jsonEnd + 1);
  }
}
