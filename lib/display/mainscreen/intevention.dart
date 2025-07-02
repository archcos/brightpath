import 'package:flutter/material.dart';

class InterventionScreen extends StatelessWidget {
  final List<Map<String, String>> interventions = [
    {
      'title': 'One-on-One Counseling',
      'date': 'July 5, 2025',
      'description': 'Discuss academic challenges and personal concerns.',
    },
    {
      'title': 'Peer Tutoring',
      'date': 'July 10, 2025',
      'description': 'Math remedial sessions with peers.',
    },
    {
      'title': 'Parent Meeting',
      'date': 'July 15, 2025',
      'description': 'Discuss student behavior and performance.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interventions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implement add new intervention screen
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: interventions.length,
        itemBuilder: (context, index) {
          final item = interventions[index];
          return Card(
            color: Colors.indigo.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(
                item['title']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(item['description']!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(item['date']!, style: const TextStyle(color: Colors.white60)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white54),
                onPressed: () {
                  // Mark as completed or show status
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
