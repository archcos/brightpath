import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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

  // Replace if folder or bucket changes
  final String bucket = 'audio';
  final String prefix = 'audio'; // Folder inside bucket

  List<String> audioFiles = [];
  bool loadingList = true;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    _fetchAudioFiles();
  }

  /* ─────── Fetch audio files from Supabase ─────── */
  Future<void> _fetchAudioFiles() async {
    try {
      final objects = await supabase.storage.from(bucket).list(path: prefix);

      setState(() {
        audioFiles = objects.map((o) => o.name).toList();
        loadingList = false;
      });

      if (audioFiles.isEmpty) {
        _showError('No audio files found in $bucket/$prefix.');
      }
    } catch (e) {
      _showError('Could not fetch audio files: $e');
      setState(() => loadingList = false);
    }
  }

  /* ─────── Get public URL for a file ─────── */
  String _publicUrlFor(String fileName) {
    final fullPath = '$prefix/$fileName';
    final url = supabase.storage.from(bucket).getPublicUrl(fullPath);

    if (url.isEmpty) {
      throw Exception('Public URL for $fullPath is empty');
    }
    return url;
  }

  /* ─────── Transcribe using AssemblyAI ─────── */
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

    // Poll until completed
    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      final statusRes = await http.get(
        Uri.parse('https://api.assemblyai.com/v2/transcript/$id'),
        headers: {'authorization': assemblyApiKey},
      );
      final data = jsonDecode(statusRes.body);
      if (data['status'] == 'completed') return data['text'];
      if (data['status'] == 'error') throw Exception('Transcription failed: ${data['error']}');
    }
  }

  /* ─────── Summarize with Gemini ─────── */
  Future<String> _summarise(String transcript) async {
    final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Summarize this transcription without explaining that its a transcription. '
                  'Just summarize everything that was talk. If a mention of Assignment, Quiz, or any other things that has date. Make display in bullet form like Assignment, Deadline: July 7, 2025. Put the EXACT DATE by comparing the date of the date of processing the upload date of file.'
                  'do it that way for others too like Quizzes and others that has date. Stop using asterisks symbols.'
                  'Lastly, categorize the topic in the summary, if talks about Science, Math, English, Filipino and make it the Subject and the Topic of summary will be the main topic like about Addition or what:'
                  '\n$transcript'}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error: ${response.body}');
    }

    return (jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'] as String).trim();
  }

  /* ─────── Process file (transcribe + summarize) ─────── */
  Future<void> _process(String fileName) async {
    setState(() => processing = true);

    try {
      final doc = await firestore.collection('summaries').doc(fileName).get();
      String summary;

      if (doc.exists) {
        summary = doc['summary'];
      } else {
        final audioUrl = _publicUrlFor(fileName);
        debugPrint("🔗 Public audio URL: $audioUrl");

        final transcript = await _transcribe(audioUrl);
        summary = await _summarise(transcript);

        await firestore.collection('summaries').doc(fileName).set({
          'transcript': transcript,
          'summary': summary,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      _showSummaryDialog(fileName, summary);
    } catch (e) {
      _showError('Processing failed: $e');
    } finally {
      setState(() => processing = false);
    }
  }

  /* ─────── UI helpers ─────── */
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSummaryDialog(String file, String summary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Summary – $file'),
        content: SingleChildScrollView(child: Text(summary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
        ],
      ),
    );
  }

  /* ─────── Build UI ─────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio-to-Summary')),
      body: loadingList
          ? const Center(child: CircularProgressIndicator())
          : processing
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: audioFiles.length,
        itemBuilder: (_, i) {
          final file = audioFiles[i];
          return ListTile(
            leading: const Icon(Icons.audiotrack),
            title: Text(file),
            onTap: () => _process(file),
          );
        },
      ),
    );
  }
}
