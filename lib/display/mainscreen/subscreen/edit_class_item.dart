// lib/edit_task_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditTaskScreen extends StatefulWidget {
  final String classId;
  final String collectionName;
  final List<String> fields;
  final String? documentId;
  final Map<String, dynamic>? existingData;

  const EditTaskScreen({
    super.key,
    required this.classId,
    required this.collectionName,
    required this.fields,
    this.documentId,
    this.existingData,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  String? _dueDate;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field] = TextEditingController(
        text: widget.existingData?[field]?.toString() ?? '',
      );
      if (field == 'dueDate') {
        _dueDate = widget.existingData?[field]?.toString();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dueDate ?? '') ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = picked.toIso8601String().split('T').first);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{};
    for (final field in widget.fields) {
      if (field == 'dueDate') {
        data[field] = _dueDate ?? '';
      } else {
        data[field] = _controllers[field]!.text.trim();
      }
    }

    final ref = FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .collection(widget.collectionName);

    if (widget.documentId != null) {
      await ref.doc(widget.documentId).update(data);
    } else {
      await ref.add(data);
    }

    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.documentId == null ? "Add" : "Edit"} ${widget.collectionName}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: widget.fields.map((field) {
              if (field == 'dueDate') {
                return ListTile(
                  title: const Text('Due Date'),
                  subtitle: Text(_dueDate ?? 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDueDate(context),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: _controllers[field],
                  decoration: InputDecoration(
                    labelText: field,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: (field == 'description' || field == 'summary') ? 8 : 1,
                  minLines: (field == 'description' || field == 'summary') ? 3 : 1,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
              );

            }).toList()
              ..add(
                const SizedBox(height: 20),
              )
              ..add(
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
          ),
        ),
      ),
    );
  }
}
