import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../sidebar/task_extract.dart';

class AudioProcessor {
  final String teacherEmail;
  final String classId;
  final String assemblyApiKey;
  final String geminiApiKey;

  final supabase = Supabase.instance.client;
  final firestore = FirebaseFirestore.instance;

  AudioProcessor({
    required this.teacherEmail,
    required this.classId,
    required this.assemblyApiKey,
    required this.geminiApiKey,
  });

  Future<void> runForToday() async {
    final bucket = 'audio';
    final prefix = teacherEmail;
    final today = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayStr = DateFormat('yyyyMMdd').format(today);

    print('[AudioProcessor] Running for date: $todayStr');
    print('[AudioProcessor] Fetching files from: $bucket/$prefix');

    final objects = await supabase.storage.from(bucket).list(path: prefix);
    final files = objects.map((o) => o.name).where((f) => f.startsWith(todayStr)).toList();

    print('[AudioProcessor] Found ${files.length} file(s) for today');

    for (final file in files) {
      await _processFile(file, bucket, prefix);
    }

    print('[AudioProcessor] Done processing all files.');
  }

  Future<void> _processFile(String fileName, String bucket, String prefix) async {
    print('[AudioProcessor] Processing file: $fileName');

    final docRef = firestore.collection('classes').doc(classId).collection('summaries').doc(fileName);
    final doc = await docRef.get();
    if (doc.exists) {
      print('[AudioProcessor] Skipped – already summarized.');
      return;
    }

    final audioUrl = supabase.storage.from(bucket).getPublicUrl('$prefix/$fileName');
    print('[AudioProcessor] Public URL: $audioUrl');

    try {
      final transcript = await _transcribe(audioUrl);
      print('[AudioProcessor] Transcript received (${transcript.length} chars)');

      final result = await _summarise(transcript);
      print('[AudioProcessor] Summary complete');
      print(' - Subject: ${result['subject']}');
      print(' - Topic: ${result['topic']}');

      await docRef.set({
        'transcript': transcript,
        'summary': result['summary'] ?? '',
        'subject': result['subject'] ?? 'Unknown',
        'topic': result['topic'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final extractor = TaskExtractor(firestore, geminiApiKey);
      await extractor.run(classId: classId, summary: result['summary'] ?? '', subject: result['subject'] ?? 'Unknown');

      print('[AudioProcessor] Stored summary in Firestore');
    } catch (e) {
      print('[AudioProcessor] Error processing $fileName: $e');
    }
  }

  Future<String> _transcribe(String audioUrl) async {
    print('[AudioProcessor] Starting transcription...');
    final res = await http.post(
      Uri.parse('https://api.assemblyai.com/v2/transcript'),
      headers: {
        'authorization': assemblyApiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({'audio_url': audioUrl}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to start transcription: ${res.body}');
    }

    final id = jsonDecode(res.body)['id'];
    print('[AudioProcessor] Transcription job started: $id');

    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      final statusRes = await http.get(
        Uri.parse('https://api.assemblyai.com/v2/transcript/$id'),
        headers: {'authorization': assemblyApiKey},
      );
      final data = jsonDecode(statusRes.body);

      if (data['status'] == 'completed') {
        print('[AudioProcessor] Transcription completed');
        return data['text'];
      }

      if (data['status'] == 'error') {
        throw Exception('Transcription failed: ${data['error']}');
      }

      print('[AudioProcessor] Transcription status: ${data['status']}...');
    }
  }

  Future<Map<String, String>> _summarise(String transcript) async {
    print('[AudioProcessor] Sending to Gemini for summarization...');

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

    final text = (jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'] as String).trim();

    final subjectRegex = RegExp(r'Subject:\s*(.+)', caseSensitive: false);
    final topicRegex = RegExp(r'Topic:\s*(.+)', caseSensitive: false);

    final subjectMatch = subjectRegex.firstMatch(text);
    final topicMatch = topicRegex.firstMatch(text);

    final cleanedSummary = text
        .replaceAll(subjectMatch?.group(0) ?? '', '')
        .replaceAll(topicMatch?.group(0) ?? '', '')
        .trim();

    return {
      'summary': cleanedSummary,
      'subject': subjectMatch?.group(1)?.trim() ?? 'Unknown',
      'topic': topicMatch?.group(1)?.trim() ?? 'Unknown',
    };
  }
}
