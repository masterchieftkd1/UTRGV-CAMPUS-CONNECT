import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.orange,
      ),

      // ----------------------------------------------------------------------
      //   STREAM CHAT ROOMS WHERE THIS USER IS A PARTICIPANT
      // ----------------------------------------------------------------------
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("chatRooms")
            .where("participants", arrayContains: currentUid)
            .orderBy("lastMessageTime", descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!.docs;

          if (rooms.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final data =
                  room.data() as Map<String, dynamic>? ?? {};

              // ------------------------------------------------------------------
              // SAFETY: Ensure participants exist
              // ------------------------------------------------------------------
              final List participants =
                  (data["participants"] ?? []) as List;

              if (participants.length < 2) {
                return const SizedBox.shrink();
              }

              final otherId =
                  participants.firstWhere((id) => id != currentUid);

              final lastMsg = (data["lastMessage"] ?? "") as String;
              final lastFrom = (data["lastMessageFrom"] ?? "") as String;

              final preview =
                  lastFrom == currentUid ? "You: $lastMsg" : lastMsg;

              // ------------------------------------------------------------------
              //   LOAD OTHER USER DATA
              // ------------------------------------------------------------------
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

                  final String email =
                      userData["email"]?.toString() ?? "Unknown User";

                  return ListTile(
                    leading:
                        const Icon(Icons.person, color: Colors.orange),

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
