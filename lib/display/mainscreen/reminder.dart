import 'package:flutter/material.dart';

class ReminderScreen extends StatelessWidget {
  final List<Map<String, String>> reminders = [
    {
      'title': 'Submit report',
      'description': 'Send the weekly sales report to the manager.',
      'time': 'Today - 5:00 PM',
    },
    {
      'title': 'Team Meeting',
      'description': 'Discuss app update progress.',
      'time': 'Tomorrow - 10:00 AM',
    },
    {
      'title': 'Pay Bills',
      'description': 'Water and electricity due.',
      'time': 'July 5 - 11:59 PM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to a new reminder creation page (to be implemented)
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Card(
            color: Colors.indigo.shade800,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              title: Text(
                reminder['title']!,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(reminder['description']!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(reminder['time']!, style: const TextStyle(color: Colors.white60)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: () {
                  // Handle delete reminder
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
