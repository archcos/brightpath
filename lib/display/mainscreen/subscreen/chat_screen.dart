import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String userEmail;
  final String receiverEmail;

  const ChatScreen({
    super.key,
    required this.userEmail,
    required this.receiverEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final isSending = ValueNotifier(false);
  String? _receiverName;

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: 'Enter your message…',
                  hintStyle: TextStyle(color: Colors.black54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isSending,
            builder: (_, sending, __) => IconButton(
              icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
              onPressed: sending
                  ? null
                  : () {
                final txt = _controller.text;
                if (txt.isEmpty) return;
                isSending.value = true;
                _send(txt).then((_) {
                  Future.delayed(const Duration(milliseconds: 300),
                          () => isSending.value = false);
                });
              },
            ),
          ),
        ],
      ),
    );
  }


  String _chatId() {
    final ids = [widget.userEmail, widget.receiverEmail]..sort();
    return ids.join('_');
  }

  Stream<QuerySnapshot> _messages() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId())
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId())
        .set({'participants': [widget.userEmail, widget.receiverEmail]},
        SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId())
        .collection('messages')
        .add({
      'senderEmail': widget.userEmail,
      'recipientEmail': widget.receiverEmail,
      'content': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _fetchReceiverName() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverEmail)
        .get();
    if (mounted) {
      setState(() =>
      _receiverName = '${doc['name']}');
    }
  }

  Future<void> _markRead() async {
    final qs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId())
        .collection('messages')
        .where('recipientEmail', isEqualTo: widget.userEmail)
        .where('isRead', isEqualTo: false)
        .get();
    for (var d in qs.docs) {
      await d.reference.update({'isRead': true});
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  String _ts(Timestamp? ts) =>
      ts == null ? 'Pending…' : DateFormat('MM-dd hh:mm a').format(ts.toDate());

  @override
  void initState() {
    super.initState();
    _fetchReceiverName();
    _markRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    isSending.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_receiverName ?? 'Chat',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.receiverEmail,
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _messages(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final msgs = snap.data!.docs;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _scrollToBottom();
                      });
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: msgs.length,
                        itemBuilder: (ctx, i) {
                          final m = msgs[i];
                          final me = m['senderEmail'] == widget.userEmail;
                          return Align(
                            alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: me ? Colors.blue[600] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: me
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(m['content'],
                                      style: TextStyle(
                                          color: me ? Colors.white : Colors.black)),
                                  const SizedBox(height: 2),
                                  Text(_ts(m['timestamp']),
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.black54)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: isKeyboardOpen ? keyboardHeight + 72 : 72),
              ],
            ),
          ),
          Positioned(
            bottom: isKeyboardOpen ? keyboardHeight : 0,
            left: 0,
            right: 0,
            child: _buildInput(),
          ),
        ],
      ),
    );
  }

}

