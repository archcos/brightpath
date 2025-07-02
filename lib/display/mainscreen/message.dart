import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'subscreen/message_chat.dart';

class MessagesListPage extends StatelessWidget {
  final String? userId;

  MessagesListPage({required this.userId});

  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {"id": doc.id, ...doc.data()})
        .toList());
  }

  Stream<Map<String, dynamic>?> getLastMessage(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null);
  }

  // Stream for unread count
  Stream<int> getUnreadCount(String chatId, String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.length;
    });
  }

  // Fetch the chatmate's name (firstName and lastName) and ID for display
  Stream<Map<String, dynamic>> getChatmateInfo(String chatId, String currentUserId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get()
        .then((chatDoc) {
      final participants = chatDoc['participants'] as List;
      final chatmateId = participants.firstWhere((id) => id != currentUserId);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(chatmateId)
          .get()
          .then((userDoc) {
        return {
          'fullName': "${userDoc['firstName']} ${userDoc['lastName']}",
          'id': chatmateId,
        };
      });
    }).asStream();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Pending...";
    final dateTime = timestamp.toDate();
    return DateFormat('MM-dd hh:mm a').format(dateTime);
  }

  // Mark messages as read when opening the chat
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('recipient', isEqualTo: userId)
        .where('isRead', isEqualTo: true)
        .get();

    for (var messageDoc in messagesSnapshot.docs) {
      await messageDoc.reference.update({'isRead': true});
    }
  }

  // Helper function to get initials from a full name
  String getInitials(String fullName) {
    final nameParts = fullName.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else {
      return nameParts[0][0].toUpperCase(); // Handle case if only first name exists
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        elevation: 5,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getUserChats(userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text(
                  "No conversations yet.",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ));
          }

          // Fetch chats
          final chats = snapshot.data!;

          // Fetch last message for sorting
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(chats.map((chat) async {
              final lastMessage = await getLastMessage(chat['id']).first;
              return {
                ...chat,
                'lastMessageTimestamp': lastMessage?['timestamp'],
              };
            })),
            builder: (context, sortedSnapshot) {
              if (sortedSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (sortedSnapshot.hasError || !sortedSnapshot.hasData) {
                return const Center(
                    child: Text(
                      "Error loading chats.",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ));
              }

              // Sort chats based on last message timestamp
              final sortedChats = sortedSnapshot.data!;
              sortedChats.sort((a, b) {
                final aTimestamp = a['lastMessageTimestamp'] as Timestamp?;
                final bTimestamp = b['lastMessageTimestamp'] as Timestamp?;
                if (aTimestamp == null || bTimestamp == null) {
                  return 0; // If timestamp is missing, keep order
                }
                return bTimestamp.compareTo(aTimestamp); // Descending order
              });

              // Build ListView with sorted chats
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: sortedChats.length,
                itemBuilder: (context, index) {
                  final chat = sortedChats[index];

                  return StreamBuilder<Map<String, dynamic>>(
                    stream: getChatmateInfo(chat['id'], userId!),
                    builder: (context, nameSnapshot) {
                      if (nameSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final chatmateName =
                          nameSnapshot.data?['fullName'] ?? "Unknown User";
                      // final chatmateId = nameSnapshot.data?['id'] ?? "Unknown ID";
                      final chatmateInitials = getInitials(chatmateName);

                      return StreamBuilder<Map<String, dynamic>?>(
                        stream: getLastMessage(chat['id']),
                        builder: (context, lastMessageSnapshot) {
                          String lastMessage = "No messages yet";
                          String lastTime = "Pending...";

                          if (lastMessageSnapshot.hasData) {
                            final message = lastMessageSnapshot.data!;
                            lastMessage = message['content'] ?? "No messages";
                            lastTime = formatTimestamp(
                                message['timestamp'] as Timestamp?);
                          }

                          return StreamBuilder<int>(
                            stream: getUnreadCount(chat['id'], userId!),
                            builder: (context, unreadSnapshot) {
                              final unreadCount = unreadSnapshot.data ?? 0;

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blueAccent,
                                    child: Text(
                                      chatmateInitials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chatmateName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          unreadCount > 0
                                              ? "$lastMessage ($unreadCount unread)"
                                              : lastMessage,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14, color: Colors.black54),
                                        ),
                                      ),
                                      Text(
                                        lastTime,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: unreadCount > 0
                                      ? CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.red,
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  )
                                      : null,
                                  onTap: () async {
                                    await markMessagesAsRead(chat['id'], userId!);

                                    final receiverId = chat['participants']
                                        .firstWhere((id) => id != userId);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          userId: userId!,
                                          receiverId: receiverId,
                                        ),
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
          );
        },
      ),
    );
  }
}
