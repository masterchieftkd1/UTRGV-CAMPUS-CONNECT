import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.orange,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: currentUid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!.docs;

          if (rooms.isEmpty) {
            return const Center(child: Text("No messages yet."));
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final data = rooms[index].data() as Map<String, dynamic>? ?? {};

              // Fallback safety
              final List participants = (data["participants"] ?? []);

              // Determine the other user
              final String otherId = participants
                  .firstWhere((id) => id != currentUid)
                  .toString();

              final String lastMsg = data["lastMessage"]?.toString() ?? "";
              final String lastFrom = data["lastMessageFrom"]?.toString() ?? "";

              // Format preview
              final preview = lastFrom == currentUid
                  ? "You: $lastMsg"
                  : lastMsg;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(otherId)
                    .get(),

                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(
                      title: Text("Loading user..."),
                    );
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};

                  final email = userData["email"]?.toString() ?? "Unknown User";

                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.orange),
                    title: Text(email),
                    subtitle: Text(
                      preview.isEmpty ? "(No messages yet)" : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: otherId,
                            otherUserEmail: email,
                          ),
                        ),
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
