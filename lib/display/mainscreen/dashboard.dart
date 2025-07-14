import 'package:bpath/display/mainscreen/sidebar/my_children.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'calendar.dart';
import 'intevention.dart';
import 'message.dart';
import 'parent_dashboard.dart';
import 'reminder.dart';
import 'sidebar/audio_summary.dart';
import 'sidebar/contact_us.dart';
import 'sidebar/profile.dart';
import 'teacher_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

late Map<String, int> _navIndexMap;

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;
  String? _userType;

  late final List<Widget> _pages = []; // <-- initialized later
  late final Stream<int> _unreadCount;
  final ValueNotifier<int> _pendingNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    _unreadCount = FirebaseFirestore.instance
        .collectionGroup('messages')                       // every “messages” sub‑collection
        .where('recipientEmail',
        isEqualTo: FirebaseAuth.instance.currentUser?.email)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);

    _loadUserType();
  }


  Future<void> _loadUserType() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (!mounted || !doc.exists) return;

      final type = doc.data()?['type'];
      if (type == null) return;

      setState(() {
        _userType = type;
        final homePage = (type == 'Parent')
            ? const DashboardHome()
            : const TeacherDashboardPage();

        _pages.addAll([
          homePage,
          const CalendarScreen(),
          if (type == 'Parent') ReminderScreen(pendingNotifier: _pendingNotifier),
          if (type == 'Parent') InterventionScreen(),
          MessagesListPage(userEmail: email),
        ]);

        _navIndexMap = {
          'home': 0,
          'calendar': 1,
          if (type == 'Parent') ...{
            'reminder': 2,
            'intervention': 3,
            'message': 4,
          } else ...{
            'message': 2,
          }
        };
      });
    } catch (e, stack) {
      debugPrint('Error loading user type: $e');
      // Optional: report to Crashlytics or log
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  @override
  void dispose() {
    _pendingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.7;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 70),
              Stack(
                children: [
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: Image.asset('assets/header.png'),
                  ),
                  const SizedBox(height: 100),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                        onPressed: _toggleSidebar,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _isSidebarOpen ? _toggleSidebar : null,
                  child: (_pages.isEmpty)
                      ? const Center(child: CircularProgressIndicator())
                      : IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ),

            ],
          ),
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            right: _isSidebarOpen ? 0 : -sidebarWidth,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: sidebarWidth,
              child: Material(
                color: Colors.indigo.shade700,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Center(
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundImage: user?.photoURL != null
                                      ? NetworkImage(user!.photoURL!)
                                      : const AssetImage('assets/defavatar.png') as ImageProvider,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                user?.displayName ?? user?.email ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          title: const Text('Profile', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.person, color: Colors.white),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            );
                          },
                        ),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType != 'Teacher') return const SizedBox();
                            return ListTile(
                              title: const Text('Create Class', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.people_rounded, color: Colors.white),
                              onTap: () {
                                Navigator.pushNamed(context, '/student');
                              },
                            );
                          },
                        ),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType != 'Parent') return const SizedBox();
                            return ListTile(
                              title: const Text('My Children', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.child_care_rounded, color: Colors.white),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const MyChildrenPage()),
                                );
                              },
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('Messages', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.message_rounded, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(_navIndexMap['message']!);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Home', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.home, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(_navIndexMap['home']!);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Calendar', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.calendar_month, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(_navIndexMap['calendar']!);
                            _toggleSidebar();
                          },
                        ),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType == 'Admin' || userType == "Teacher" ) return const SizedBox();
                            return ListTile(
                              title: const Text('Reminders', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.notifications, color: Colors.white),
                              onTap: () {
                                _onBottomNavTap(_navIndexMap['reminder']!);
                              },
                            );
                          },
                        ),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType == 'Admin' || userType == "Teacher" ) return const SizedBox();
                            return ListTile(
                              title: const Text('Interventions', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.waving_hand, color: Colors.white),
                              onTap: () {
                                _onBottomNavTap(_navIndexMap['intervention']!);
                              },
                            );
                          },
                        ),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType == 'Admin') return const SizedBox();
                            return ListTile(
                              title: const Text('Contact Us', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.contact_support_rounded, color: Colors.white),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                                );
                              },
                            );
                          },
                        ),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType != 'Admin') return const SizedBox();
                            return ListTile(
                              title: const Text('Test', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AudioSummaryPage()),
                                );
                              },
                            );
                          },
                        ),

                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                            final userType = snapshot.data!.get('type');
                            if (userType != 'Admin') return const SizedBox();
                            return ListTile(
                              title: const Text('Admin Configurations', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
                              onTap: () {
                                Navigator.pushNamed(context, '/admin');
                              },
                            );
                          },
                        ),
                        const Spacer(),
                        ListTile(
                          title: const Text('Logout', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.logout, color: Colors.white),
                          onTap: () async {
                            _toggleSidebar();
                            await GoogleSignIn().signOut();
                            await FirebaseAuth.instance.signOut();
                            if (!context.mounted) return;
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: _pendingNotifier,
          builder: (context, pending, _) {
            return StreamBuilder<int>(
              stream: _unreadCount,
              builder: (context, unreadSnap) {
                final unread = unreadSnap.data ?? 0;

                return BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  selectedItemColor: Colors.indigo,
                  onTap: _onBottomNavTap,
                  items: [
                    const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                    const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),

                    if (_userType == 'Parent')
                      BottomNavigationBarItem(
                        label: 'Reminder',
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.add_alert),
                            if (pending > 0)
                              Positioned(
                                right: -2,
                                top:  -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    pending > 99 ? '99+' : '$pending',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    if (_userType == 'Parent')
                      const BottomNavigationBarItem(icon: Icon(Icons.waving_hand), label: 'Interventions'),

                    BottomNavigationBarItem(
                      label: 'Message',
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.message_rounded),
                          if (unread > 0)
                            Positioned(
                              right: -2,
                              top:  -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        )
    );
  }
}

