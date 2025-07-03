
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'subscreen/dashboard_summary.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
