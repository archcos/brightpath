import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final List<String> statusOptions = ['Active', 'Inactive', 'Suspended'];
  final List<String> typeOptions = ['Parent', 'Teacher', 'Admin'];

  String searchQuery = '';
  String? selectedStatus;
  String? selectedType;

  Future<void> updateUserField(String docId, String field, String value) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({field: value});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel - Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Filter by Status'),
                    value: selectedStatus,
                    isExpanded: true,
                    items: [null, ...statusOptions].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status ?? 'All'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedStatus = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Filter by Type'),
                    value: selectedType,
                    isExpanded: true,
                    items: [null, ...typeOptions].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type ?? 'All'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedType = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = doc.id.toLowerCase();
                  final status = (data['status'] ?? '').toString();
                  final type = (data['type'] ?? '').toString();

                  final matchesSearch = email.contains(searchQuery);
                  final matchesStatus = selectedStatus == null || status == selectedStatus;
                  final matchesType = selectedType == null || type == selectedType;

                  return matchesSearch && matchesStatus && matchesType;
                }).toList();

                if (users.isEmpty) return const Center(child: Text('No matching users'));

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final data = userDoc.data() as Map<String, dynamic>;
                    final email = userDoc.id;
                    final status = data['status'] ?? 'Unknown';
                    final type = data['type'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Status:'),
                                const SizedBox(width: 10),
                                DropdownButton<String>(
                                  value: statusOptions.contains(status) ? status : null,
                                  items: statusOptions.map((option) {
                                    return DropdownMenuItem(value: option, child: Text(option));
                                  }).toList(),
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      updateUserField(email, 'status', newValue);
                                    }
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('Type:'),
                                const SizedBox(width: 24),
                                DropdownButton<String>(
                                  value: typeOptions.contains(type) ? type : null,
                                  items: typeOptions.map((option) {
                                    return DropdownMenuItem(value: option, child: Text(option));
                                  }).toList(),
                                  onChanged: (newValue) async {
                                    if (newValue == null || newValue == type) return;

                                    final isPromotingToAdmin = newValue == 'Admin' && type != 'Admin';
                                    final isDemotingFromAdmin = newValue != 'Admin' && type == 'Admin';

                                    bool confirmed = true;

                                    if (isPromotingToAdmin) {
                                      confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Confirm Admin Role'),
                                          content: Text('Are you sure you want to assign "$email" as an Admin?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                                          ],
                                        ),
                                      ) ??
                                          false;
                                    } else if (isDemotingFromAdmin) {
                                      confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Remove Admin Role'),
                                          content: Text('Are you sure you want to remove Admin rights from "$email"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                                          ],
                                        ),
                                      ) ??
                                          false;
                                    }

                                    if (confirmed) {
                                      updateUserField(email, 'type', newValue);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
