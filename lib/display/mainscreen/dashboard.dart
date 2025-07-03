import 'package:brightpath/display/mainscreen/calendar.dart';
import 'package:brightpath/display/mainscreen/intevention.dart';
import 'package:brightpath/display/mainscreen/message.dart';
import 'package:brightpath/display/mainscreen/reminder.dart';
import 'package:brightpath/display/mainscreen/sidebar/contact_us.dart';
import 'package:brightpath/display/mainscreen/sidebar/test.dart';
import 'package:brightpath/display/mainscreen/subscreen/dashboard_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'parent_dashboard.dart';
import 'sidebar/add_child.dart';
import 'sidebar/profile.dart';
import 'teacher_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;
  String? _userType;


  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();

    if (mounted && doc.exists) {
      setState(() {
        _userType = doc.data()?['type']; // ex: "Teacher" or "Parent"
      });
    }
  }

  List<Widget> get _pages {
    final homePage = (_userType == 'Parent')
        ? const DashboardHome()       // <— parent / default UI
        : const TeacherDashboardPage(); // <— your teacher UI

    return [
      homePage,
      const CalendarScreen(),
      ReminderScreen(),
      InterventionScreen(),
      MessagesListPage(
        userId: FirebaseAuth.instance.currentUser?.email ?? '',
      ),
    ];
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
                  child: _pages[_selectedIndex],
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
                            if (userType != 'Parent') return const SizedBox();
                            return ListTile(
                              title: const Text('Register Child', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.child_care_rounded, color: Colors.white),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddChildScreen()),
                                );
                              },
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('Messages', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.message_rounded, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(4);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Home', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.home, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(0);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Calendar', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.calendar_month, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(1);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Reminders', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.notifications, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(2);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Interventions', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.waving_hand, color: Colors.white),
                          onTap: () {
                            _onBottomNavTap(3);
                            _toggleSidebar();
                          },
                        ),
                        ListTile(
                          title: const Text('Contact Us', style: TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.contact_support_rounded, color: Colors.white),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ContactUsScreen()),
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
                            if (userType != 'Teacher') return const SizedBox();
                            return ListTile(
                              title: const Text('Teacher Configurations', style: TextStyle(color: Colors.white)),
                              leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
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
                            if (userType != 'Teacher') return const SizedBox();
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.add_alert), label: 'Reminder'),
          BottomNavigationBarItem(icon: Icon(Icons.waving_hand), label: 'Interventions'),
          BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Message'),
        ],
      ),
    );
  }
}

