import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String receiverId;

  ChatScreen({required this.userId, required this.receiverId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? receiverName;
  final ValueNotifier<bool> isSending = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _fetchReceiverName();
    _markMessagesAsRead();  // Mark messages as read when the screen is opened
  }

  Future<void> _fetchReceiverName() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverId)
        .get();
    setState(() {
      receiverName =
      "${userDoc['firstName']} ${userDoc['lastName']}";
    });
  }

  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_getChatId())
        .collection('messages')
        .add({
      'senderId': widget.userId,
      'recipientId': widget.receiverId,
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,  // New messages are initially unread
    });

    _controller.clear();
    _scrollToBottom();
  }

  String _getChatId() {
    final ids = [widget.userId, widget.receiverId];
    ids.sort();
    return ids.join('_');
  }

  Stream<QuerySnapshot> getMessages() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(_getChatId())
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
      );
    }
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Pending...";
    final dateTime = timestamp.toDate();
    return DateFormat('MM-dd-yyyy hh:mm a').format(dateTime);
  }

  // Mark all unread messages as read when the chat screen is opened
  Future<void> _markMessagesAsRead() async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(_getChatId())
        .collection('messages')
        .where('recipientId', isEqualTo: widget.userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var messageDoc in messagesSnapshot.docs) {
      await messageDoc.reference.update({'isRead': true});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    isSending.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              receiverName ?? "Chat", // Main title
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.receiverId, // Subtitle
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(10),
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        children: [
                          const TextSpan(
                            text: "Please update the Status of your ticket once you claim/give an item. ",
                          ),
                          TextSpan(
                            text: "Click Here",
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, '/my-tickets');
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat messages display area
          Expanded(
            child: SingleChildScrollView(
              reverse: true,  // Ensure scrolling starts from the bottom
              controller: _scrollController,
              child: StreamBuilder<QuerySnapshot>(
                stream: getMessages(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No messages yet"));
                  }

                  final messages = snapshot.data!.docs;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,  // Allows ListView to fit inside SingleChildScrollView
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isSender = message['senderId'] == widget.userId;

                      return Align(
                        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSender ? Colors.blue[600] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isSender
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['content'],
                                style: TextStyle(
                                    color: isSender ? Colors.white : Colors.black),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                formatTimestamp(message['timestamp'] as Timestamp?),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.black54),
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
          ),

          // Message input area
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                      decoration: const InputDecoration(
                        hintText: 'Enter your message...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isSending,
                  builder: (context, sending, child) {
                    return IconButton(
                      icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                      onPressed: sending
                          ? null // Disable the button when sending
                          : () {
                        if (_controller.text.isNotEmpty) {
                          isSending.value = true; // Disable the button
                          String userMessage = _controller.text;

                          // Re-enable the button after 1 second
                          Future.delayed(const Duration(seconds: 1), () {
                            isSending.value = false;
                          });

                          // Send the message
                          sendMessage(_controller.text);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
