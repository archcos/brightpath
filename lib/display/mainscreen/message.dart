import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'subscreen/chat_screen.dart';

class MessagesListPage extends StatefulWidget {
  final String userEmail;
  const MessagesListPage({super.key, required this.userEmail});

  @override
  State<MessagesListPage> createState() => _MessagesListPageState();
}

class _MessagesListPageState extends State<MessagesListPage> {
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _chats() =>
      FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.userEmail)
          .snapshots()
          .map((snap) {

        return snap.docs;
      });

  Stream<Map<String, dynamic>?> _last(String chatId) =>
      FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) {
        return snap.docs.isNotEmpty ? snap.docs.first.data() : null;
      });

  Stream<int> _unread(String chatId) => FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .where('recipientEmail', isEqualTo: widget.userEmail)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) {
    final c = snap.docs.length;
    return c;
  });

  Stream<Map<String, dynamic>> _mate(String chatId) => FirebaseFirestore
      .instance
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .asyncMap((doc) async {
    final data = doc.data();
    if (data == null) {
      return {'name': 'Unknown', 'email': ''};
    }
    final participants = List<String>.from(data['participants']);
    final mateEmail =
    participants.firstWhere((e) => e != widget.userEmail, orElse: () {
      return '';
    });
    final u = await FirebaseFirestore.instance
        .collection('users')
        .doc(mateEmail)
        .get();
    final displayName =
        u.data()?['name'] ?? u.data()?['displayName'] ?? mateEmail;
    return {'name': displayName, 'email': mateEmail};
  });

  String _initials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _fmtTs(Timestamp? t) => t == null
      ? 'Pending…'
      : DateFormat('MM-dd hh:mm a').format(t.toDate());

  Future<void> _markAllRead(String chatId) async {
    final qs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('recipientEmail', isEqualTo: widget.userEmail)
        .where('isRead', isEqualTo: false)
        .get();
    for (var d in qs.docs) {
      await d.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Conversations', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _chats(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snap.data!;
          if (chats.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: chats.length,
            itemBuilder: (ctx, i) {
              final chatId = chats[i].id;

              return StreamBuilder<Map<String, dynamic>>(
                stream: _mate(chatId),
                builder: (ctx, mateSnap) {
                  if (mateSnap.hasError) {
                    return const ListTile(title: Text('Error loading user…'));
                  }
                  if (!mateSnap.hasData) return const SizedBox.shrink();

                  final mate = mateSnap.data!;
                  final name = mate['name'] as String;
                  final email = mate['email'] as String;
                  final initials = _initials(name);

                  return StreamBuilder<Map<String, dynamic>?>(
                    stream: _last(chatId),
                    builder: (ctx, lastSnap) {
                      if (lastSnap.hasError) {
                        return const ListTile(title: Text('Error loading snapshot…'));
                      }
                      final last = lastSnap.data;
                      final lastTxt = last?['content'] ?? 'No messages yet';
                      final lastTime = _fmtTs(last?['timestamp']);

                      return StreamBuilder<int>(
                        stream: _unread(chatId),
                        builder: (ctx, unSnap) {
                          if (unSnap.hasError) {
                            return const ListTile(title: Text('Error loading snaps…'));
                          }
                          final unread = unSnap.data ?? 0;

                          return Card(
                            color: Colors.grey[100],
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Text(initials,
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black)
                              ),
                              subtitle: Row(children: [
                                Expanded(
                                  child: Text(
                                    unread > 0 ? '$lastTxt ($unread)' : lastTxt,
                                    overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.black54)
                                  ),
                                ),
                                Text(lastTime,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ]),
                              trailing: unread > 0
                                  ? CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.red,
                                child: Text('$unread',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11)),
                              )
                                  : null,
                              onTap: () async {
                                await _markAllRead(chatId);
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                        userEmail: widget.userEmail,
                                        receiverEmail: email),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'messageFab',
        onPressed: _newMessageDialog,
        child: const Icon(Icons.message),
      ),
    );
  }

  Future<void> _newMessageDialog() async {
    final emailCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send New Message'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Recipient Email')),
          TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Message'), maxLines: 4),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;

    final to = emailCtrl.text.trim();
    final text = msgCtrl.text.trim();

    if (to.isEmpty || text.isEmpty || to == widget.userEmail) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid input')));
      return;
    }

    final exists = await FirebaseFirestore.instance.collection('users').doc(to).get();
    if (!exists.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
      return;
    }

    final ids = [widget.userEmail, to]..sort();
    final chatId = ids.join('_');
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    await chatRef.set({'participants': ids}, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'senderEmail': widget.userEmail,
      'recipientEmail': to,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'archivedBy': <String>[],
    });

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(userEmail: widget.userEmail, receiverEmail: to),
      ),
    );
  }
}
