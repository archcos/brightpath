import 'package:flutter/material.dart';

class DashboardSummary extends StatelessWidget {
  final String subject;
  final String label;

  const DashboardSummary({super.key, required this.subject, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$subject - $label')),
      body: Center(
        child: Text('Welcome to $label lesson in $subject!'),
      ),
    );
  }
}
