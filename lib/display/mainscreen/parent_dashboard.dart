import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'subscreen/audio_processor.dart';
import 'subscreen/task_detail.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});
  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _hasChildInClass = true;

  bool _initialLoading = true;


  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  String _selectedDay = '';
  List<_SchedView> _schedules = [];

  String? _teacherEmail;

  DateTime _selectedDate =
  DateTime.now().toUtc().add(const Duration(hours: 8)); // PH‑time

  List<_SummaryTileData> _summariesForDate = [];
  bool _loadingSummaries = false;

  List<_TaskTile> _tasksForDate = [];
  bool _loadingTasks = false;

  String _base(String email) =>
      email.toLowerCase().replaceFirst(RegExp(r'\d+$'), '');

  Future<Map<String, String>?> _findTeacherAndClass(String studentEmail) async {
    try {
      final classDocs = await FirebaseFirestore.instance.collection('classes').get();

      for (final classDoc in classDocs.docs) {
        final studentsSnap = await classDoc.reference.collection('students').get();

        final found = studentsSnap.docs.any((doc) {
          final data = doc.data();
          return data['parent_email'] == studentEmail;
        });

        if (found) {
          return {
            'teacherEmail': classDoc.data()['teacher_email'],
            'classId': classDoc.id,
          };
        }
      }
    } catch (e) {
      debugPrint('Error in _findTeacherAndClass: $e');
    }

    return null;
  }


  Future<void> _fetchTeacherEmailAndInit(String userEmail) async {
    try {
      final info = await _findTeacherAndClass(userEmail);

      if (!mounted) return;

      if (info != null) {
        setState(() {
          _teacherEmail = info['teacherEmail'];
        });
        await _refreshForDate(); // fetch summaries, tasks, and run audio processor
      } else {
        setState(() {
          _teacherEmail = null;
          _summariesForDate.clear();
          _tasksForDate.clear();
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchTeacherEmailAndInit: $e');
      if (!mounted) return;
      setState(() {
        _teacherEmail = null;
        _summariesForDate.clear();
        _tasksForDate.clear();
      });
    }
  }

  Future<void> _loadSchedules(String email) async {
    final base = _base(email);
    final students = await FirebaseFirestore.instance.collectionGroup('students').get();
    final seenClasses = <String>{};
    final List<_SchedView> all = [];

    for (final sDoc in students.docs) {
      if (_base(sDoc.id) != base) continue;
      final classDoc = sDoc.reference.parent.parent;
      if (classDoc == null || !seenClasses.add(classDoc.id)) continue;

      final schedSnap = await classDoc.collection('schedule').get();
      for (final d in schedSnap.docs) {
        final data = d.data();
        if (data['entries'] is List) {
          for (final e in List<Map<String, dynamic>>.from(data['entries'])) {
            all.add(_SchedView(
              day: data['day'] ?? d.id,
              subject: e['subject'] ?? '',
              time: '${_formatTime(e['start'])} – ${_formatTime(e['end'])}',
            ));
          }
        } else {
          all.add(_SchedView(
            day: data['day'] ?? d.id,
            subject: data['subject'] ?? '',
            time: '${_formatTime(data['start'])} – ${_formatTime(data['end'])}',
          ));
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _schedules = all;
      _hasChildInClass = all.isNotEmpty;
    });
  }


  Future<void> _fetchSummariesForDate() async {
    if (_teacherEmail == null) return;
    if (!mounted) return;

    setState(() {
      _loadingSummaries = true;
      _summariesForDate = [];
    });

    final classSnap = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacher_email', isEqualTo: _teacherEmail)
        .limit(1)
        .get();

    if (classSnap.docs.isEmpty) {
      if (!mounted) return;
      setState(() => _loadingSummaries = false);
      return;
    }

    final classId = classSnap.docs.first.id;

    final dateStr = DateFormat('yyyyMMdd').format(_selectedDate);

    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('summaries')
        .get();

    final results = snap.docs
        .where((d) => d.id.startsWith(dateStr))
        .map((d) {
      final data = d.data();
      return _SummaryTileData(
        subject: data['subject'] ?? 'Unknown',
        topic: data['topic'] ?? 'Unknown',
        summary: data['summary'] ?? '',
      );
    })
        .toList();

    if (!mounted) return;
    setState(() {
      _summariesForDate = results;
      _loadingSummaries = false;
    });
  }

  Future<void> _fetchTasksForDate() async {
    if (_teacherEmail == null) return;
    if (!mounted) return;

    setState(() {
      _loadingTasks = true;
      _tasksForDate = [];
    });

    final formattedDate = DateFormat('MM-dd-yyyy').format(_selectedDate);

    final classSnap = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacher_email', isEqualTo: _teacherEmail)
        .limit(1)
        .get();

    if (classSnap.docs.isEmpty) {
      if (!mounted) return;
      setState(() => _loadingTasks = false);
      return;
    }

    final classId = classSnap.docs.first.id;
    final collections = ['assignments', 'quizzes', 'projects'];
    final List<_TaskTile> results = [];

    String _formatType(String collectionName) {
      switch (collectionName) {
        case 'assignments':
          return 'Assignment';
        case 'quizzes':
          return 'Quiz';
        case 'projects':
          return 'Project';
        default:
          return collectionName[0].toUpperCase() + collectionName.substring(1);
      }
    }

    for (final col in collections) {
      final snap = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection(col)
          .get();

      for (final doc in snap.docs) {
        if (doc.id.endsWith(formattedDate)) {
          final data = doc.data();
          results.add(_TaskTile(
            subject: data['subject'] ?? '',
            title: data['title'] ?? '',
            dueDate: data['dueDate'] ?? '',
            type: _formatType(col),
            description: data['description'] ?? '',
          ));

        }
      }
    }

    if (!mounted) return;
    setState(() {
      _tasksForDate = results;
      _loadingTasks = false;
    });
  }

  String _formatTime(String time24) {
    try {
      final dt = DateFormat('HH:mm').parse(time24);
      return DateFormat('h:mm a').format(dt);
    } catch (e) {
      return time24;
    }
  }

  Future<String> _getClassIdByTeacherEmail(String teacherEmail) async {
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacher_email', isEqualTo: teacherEmail)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return snap.docs.first.id;
    } else {
      throw Exception('Class not found for $teacherEmail');
    }
  }



  Future<void> _refreshForDate({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loadingSummaries = true;
        _loadingTasks = true;
      });
    }

    if (_teacherEmail != null) {
      final classSnap = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacher_email', isEqualTo: _teacherEmail)
          .limit(1)
          .get();

      if (classSnap.docs.isNotEmpty) {
        final classId = classSnap.docs.first.id;
        final String assemblyApiKey = dotenv.env['ASSEMBLY_API_KEY'] ?? '';
        final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

        // Run AudioProcessor and wait until it completes
        final processor = AudioProcessor(
          teacherEmail: _teacherEmail!,
          classId: classId,
          assemblyApiKey: assemblyApiKey,
          geminiApiKey: geminiApiKey,
        );

        await processor.runForToday();
      }
    }

    await Future.wait([
      _fetchSummariesForDate(),
      _fetchTasksForDate(),
    ]);

    if (mounted && showLoader) {
      setState(() {
        _loadingSummaries = false;
        _loadingTasks = false;
      });
    }
  }




  @override
  void initState() {
    super.initState();
    final nowPH = DateTime.now().toUtc().add(const Duration(hours: 8));
    _selectedDay = DateFormat('EEEE').format(nowPH);

    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      _loadSchedules(email);
      _fetchTeacherEmailAndInit(email).then((_) {
        if (mounted) {
          setState(() => _initialLoading = false);
        }
      });
    } else {
      _initialLoading = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initialLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Getting your lesson summary and tasks...',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }



    final user = FirebaseAuth.instance.currentUser;
    final firstName =
        user?.displayName?.split(' ').first ?? user?.email ?? 'User';
    final nowPH = DateTime.now().toUtc().add(const Duration(hours: 8));
    final filtered = _schedules.where((e) => e.day == _selectedDay).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null) {
          setState(() => _initialLoading = true); // Show "Getting your lesson..."
          await _loadSchedules(email);
          await _refreshForDate();
          setState(() => _initialLoading = false);
        }
      },

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (!_hasChildInClass) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No child is in a class yet.\n\n'
                      'Please contact your child\'s teacher to add them to a class, '
                      'or register your child first if not yet registered.',
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Welcome, $firstName!',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 12),
            StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(seconds: 1),
                      (_) => DateTime.now().toUtc().add(const Duration(hours: 8))),
              builder: (context, snapshot) {
                final dt = snapshot.data ?? nowPH;
                final formatted =
                DateFormat('EEEE, MMMM d, y – h:mm:ss a').format(dt);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(formatted,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                );
              },
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                    _refreshForDate(showLoader: false); // Just reload tiles
                  },

                  child: const Text('<'),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, y').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                    _refreshForDate(showLoader: false);
                  },

                  child: const Text('>'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.article, color: Colors.white),
                SizedBox(width: 8),
                Text('Summaries',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingSummaries)
              const Center(child: CircularProgressIndicator())
            else if (_summariesForDate.isEmpty)
              const Text('No summaries for this date.', style: TextStyle(color: Colors.white))
            else
              Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _summariesForDate.map((d) => SizedBox(
                    width: 140,
                    height: 90,
                    child: _Tile(subject: d.subject, topic: d.topic, summary: d.summary),
                  )).toList(),
                ),
              ),


            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.task_alt, color: Colors.white),
                SizedBox(width: 8),
                Text('Tasks',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingTasks)
              const Center(child: CircularProgressIndicator())
            else if (_tasksForDate.isEmpty)
              const Text('No tasks for this date.', style: TextStyle(color: Colors.white))
            else
              Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _tasksForDate.map((task) => InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailPage(
                            title: task.title,
                            subject: task.subject,
                            dueDate: task.dueDate,
                            type: task.type,
                            description: task.description,
                          ),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 140,
                      height: 100,
                      child: Card(
                        color: Colors.pink.shade100,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                  minHeight: 100,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.type,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.deepPurple,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      task.subject,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Due: ${task.dueDate}',
                                      style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),



            if (user != null) ...[
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Schedule for:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedDay,
                    items: _days
                        .map((day) => DropdownMenuItem(
                        value: day, child: Text(day)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No schedule for $_selectedDay.',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (filtered.length <= 2)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: filtered
                      .map((e) => SizedBox(
                    width: 140,
                    height: 80,
                    child: _ScheduleTile(view: e),
                  ))
                      .toList(),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filtered
                        .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                          width: 140,
                          height: 80,
                          child: _ScheduleTile(view: e)),
                    ))
                        .toList(),
                  ),
                ),

            ],
          ],
        ),
      ),
    );
  }
}


class _SchedView {
  final String day;
  final String subject;
  final String time;
  _SchedView({required this.day, required this.subject, required this.time});
}

extension StringCasingExtension on String {
  String capitalize() => length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}

class _TaskTile {
  final String subject;
  final String title;
  final String dueDate;
  final String type;
  final String description;


  _TaskTile({
    required this.subject,
    required this.title,
    required this.dueDate,
    required this.type,
    required this.description,
  });
}

class _SummaryTileData {
  final String subject;
  final String topic;
  final String summary;
  _SummaryTileData(
      {required this.subject, required this.topic, required this.summary});
}


class _Tile extends StatelessWidget {
  final String subject;
  final String topic;
  final String summary;
  const _Tile(
      {required this.subject, required this.topic, required this.summary});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade100,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _SummaryDetail(subject: subject, topic: topic, summary: summary),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.deepPurple),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: Text(topic,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final _SchedView view;
  const _ScheduleTile({required this.view});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.lightBlue.shade100,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(view.subject,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(view.time,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _SummaryDetail extends StatelessWidget {
  final String subject;
  final String topic;
  final String summary;

  const _SummaryDetail({
    required this.subject,
    required this.topic,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          subject,
          style: const TextStyle(fontSize: 20),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Main Topic: $topic',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                summary,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
