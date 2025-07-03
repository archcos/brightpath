import 'package:brightpath/display/mainscreen/calendar.dart';
import 'package:brightpath/display/mainscreen/intevention.dart';
import 'package:brightpath/display/mainscreen/message.dart';
import 'package:brightpath/display/mainscreen/reminder.dart';
import 'package:brightpath/display/mainscreen/sidebar/contact_us.dart';
import 'package:brightpath/display/mainscreen/subscreen/dashboard_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'sidebar/add_child.dart';
import 'sidebar/profile.dart';


final user = FirebaseAuth.instance.currentUser;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}


class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;

  final List<Widget> _pages = [
    const DashboardHome(),
    const CalendarScreen(),
    ReminderScreen(),
    InterventionScreen(),
    MessagesListPage(userId: user!.email),
  ];



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
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.7;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 70,),

              Stack(
                children: [

                  SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/header.png',
                      ),
                    ),
                  const SizedBox(height: 100,),

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
                    onTap: () {}, // prevent sidebar close on tap inside
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Center(
                                child:  CircleAvatar(
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
                              .doc(FirebaseAuth.instance.currentUser?.email)
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
                              .doc(FirebaseAuth.instance.currentUser?.email)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();

                            final userType = snapshot.data!.get('type');
                            if (userType != 'Admin') return const SizedBox();

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
                              .doc(FirebaseAuth.instance.currentUser?.email)
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

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    final firstName = user?.displayName?.split(' ').first ?? user?.email ?? 'User';

    final List<Map<String, dynamic>> tiles = [
      {
        'subject': 'Math',
        'label': 'Addition',
        'description': 'Lesson'
      },
      {
        'subject': 'Science',
        'label': 'Water',
        'description': 'Lesson'
      },
      {
        'subject': 'English',
        'label': 'Grammar',
        'description': 'Lesson'
      },
      {
        'subject': 'Filipino',
        'label': 'Tula',
        'description': 'Lesson'
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $firstName!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 50),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tiles.map((tile) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: DashboardTile(
                      subject: tile['subject'],
                      label: tile['label'],
                      description: tile['description'],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardSummary(
                              subject: tile['subject'],
                              label: tile['label'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 50),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tiles.map((tile) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: DashboardTile(
                      subject: tile['subject'],
                      label: tile['label'],
                      description: tile['description'],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardSummary(
                              subject: tile['subject'],
                              label: tile['label'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  final String subject;
  final String label;
  final String description;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.subject,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade100,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                subject,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20,),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovingLabel extends StatefulWidget {
  final String text;

  const _MovingLabel({required this.text});

  @override
  State<_MovingLabel> createState() => _MovingLabelState();
}

class _MovingLabelState extends State<_MovingLabel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = 40.0 * _controller.value;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: const TextStyle(fontSize: 16),
        overflow: TextOverflow.visible,
      ),
    );
  }
}
