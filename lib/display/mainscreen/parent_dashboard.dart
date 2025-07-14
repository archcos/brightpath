import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'calendar.dart';
import 'sidebar/audio_summary.dart';

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

  Future<String?> _findTeacherEmailForStudent(String studentEmail) async {
    try {
      final classDocs = await FirebaseFirestore.instance.collection('classes').get();

      for (final classDoc in classDocs.docs) {
        final studentsSnap = await classDoc.reference.collection('students').get();

        final found = studentsSnap.docs.any((doc) {
          final data = doc.data();
          return data['parent_email'] == studentEmail;
        });

        if (found) {
          return classDoc.data()['teacher_email'];
        }
      }
    } catch (e) {
      debugPrint('Error in _findTeacherEmailForStudent: $e');
    }

    return null; // Either no class found or error occurred
  }


  Future<void> _fetchTeacherEmailAndInit(String userEmail) async {
    try {
      final teacherEmail = await _findTeacherEmailForStudent(userEmail);

      if (!mounted) return;

      if (teacherEmail != null) {
        setState(() => _teacherEmail = teacherEmail);
        await _refreshForDate(); // summaries + tasks
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
              time: '${e['start']} – ${e['end']}',
            ));
          }
        } else {
          all.add(_SchedView(
            day: data['day'] ?? d.id,
            subject: data['subject'] ?? '',
            time: '${data['start']} – ${data['end']}',
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

  Future<void> _refreshForDate() async {
    await Future.wait([
      _fetchSummariesForDate(),
      _fetchTasksForDate(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    final nowPH = DateTime.now().toUtc().add(const Duration(hours: 8));
    _selectedDay = DateFormat('EEEE').format(nowPH);

    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      _loadSchedules(email);
      _fetchTeacherEmailAndInit(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;
    final firstName =
        user?.displayName?.split(' ').first ?? user?.email ?? 'User';
    final nowPH = DateTime.now().toUtc().add(const Duration(hours: 8));
    final filtered = _schedules.where((e) => e.day == _selectedDay).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null) {
          await _loadSchedules(email);
          await _refreshForDate();
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
            ElevatedButton.icon(
              icon: const Icon(Icons.graphic_eq),
              label: const Text('Audio Summary'),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AudioSummaryPage()));
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
                    _refreshForDate();
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
                    _refreshForDate();
                  },
                  child: const Text('>'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_loadingSummaries)
              const Center(child: CircularProgressIndicator())
            else if (_summariesForDate.isEmpty)
              const Text('No summaries for this date.',
                  style: TextStyle(color: Colors.white))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _summariesForDate
                      .map((d) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 140,
                      height: 90,
                      child: _Tile(
                          subject: d.subject,
                          topic: d.topic,
                          summary: d.summary),
                    ),
                  ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 10),

            if (_loadingTasks)
              const Center(child: CircularProgressIndicator())
            else if (_tasksForDate.isEmpty)
              const Text('No tasks for this date.',
                  style: TextStyle(color: Colors.white))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tasksForDate
                      .map((task) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CalendarScreen()));
                      },
                      child: SizedBox(
                        width: 140,
                        height: 100,
                        child: Card(
                          color: Colors.pink.shade100,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    task.subject,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade900,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Due: ${task.dueDate}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            )
                          ),
                        ),
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ),


            if (user != null) ...[
              Row(
                children: [
                  const Text('Schedule for: ',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
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
                Text('No schedule for $_selectedDay.',
                    style: const TextStyle(color: Colors.white))
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

/* ───────────────── Data holders ───────────────── */

class _SchedView {
  final String day;
  final String subject;
  final String time;
  _SchedView({required this.day, required this.subject, required this.time});
}

class _TaskTile {
  final String subject;
  final String title;
  final String dueDate;
  _TaskTile(
      {required this.subject, required this.title, required this.dueDate});
}

class _SummaryTileData {
  final String subject;
  final String topic;
  final String summary;
  _SummaryTileData(
      {required this.subject, required this.topic, required this.summary});
}

/* ───────────────── UI pieces ───────────────── */

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
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
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
  const _SummaryDetail(
      {required this.subject, required this.topic, required this.summary});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$subject – $topic')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(summary, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
