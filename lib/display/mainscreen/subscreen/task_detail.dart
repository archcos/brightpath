import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDetailPage extends StatelessWidget {
  final String title;
  final String subject;
  final String dueDate;
  final String type;
  final String description;

  const TaskDetailPage({
    super.key,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.type,
    required this.description,
  });

  Color getEventColor(String type) {
    switch (type) {
      case 'Assignment':
        return Colors.red;
      case 'Quiz':
        return Colors.pink;
      case 'Project':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData getEventIcon(String type) {
    switch (type) {
      case 'Assignment':
        return Icons.assignment;
      case 'Quiz':
        return Icons.quiz;
      case 'Project':
        return Icons.build_circle;
      default:
        return Icons.task;
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMMM d, y').format(parsed); // Example: July 14, 2025
    } catch (_) {
      return date; // fallback to original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Title: $title', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Subject: $subject', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Details: \n$description', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Deadline: ${_formatDate(dueDate)}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      getEventIcon(type),
                      color: getEventColor(type),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
