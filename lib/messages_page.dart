import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in.")),
      );
    }

    final currentUid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: currentUid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }

          final rooms = snapshot.data!.docs;

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final data = room.data() as Map<String, dynamic>? ?? {};

              final participants = List<String>.from(data['participants'] ?? []);
              if (participants.length != 2) return const SizedBox.shrink();

              final otherUserId =
                  participants.firstWhere((id) => id != currentUid);

              final lastMessage = data['lastMessage'] ?? '';
              final ts = data['lastMessageTime'] as Timestamp?;
              final lastFrom = data['lastMessageFrom'] ?? '';
              final seenBy =
                  List<String>.from(data['seenBy'] ?? <String>[]);

              final isLastFromMe = lastFrom == currentUid;
              final hasSeenLast = seenBy.contains(currentUid);

              // Formatting
              String subtitle = lastMessage.isEmpty
                  ? "No messages yet"
                  : (!isLastFromMe && !hasSeenLast ? "New: $lastMessage" : lastMessage);

              String timestamp = "";
              if (ts != null) {
                final time = ts.toDate();
                final now = DateTime.now();

                timestamp = now.difference(time).inDays == 0
                    ? "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"
                    : "${time.month}/${time.day}";
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnap) {
                  String email = "Unknown user";
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                    email = userData['email'] ?? email;
                  }

                  final showUnreadDot =
                      !isLastFromMe && !hasSeenLast && lastMessage.isNotEmpty;

                  return ListTile(
                    leading: Stack(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        if (showUnreadDot)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                      ],
                    ),
                    title: Text(email),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      timestamp,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'userId': otherUserId,
                          'email': email,
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
