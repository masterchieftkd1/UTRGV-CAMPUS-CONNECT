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

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
        .collection("chats")
        .where("members", arrayContains: currentUid)
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
              final roomDoc = rooms[index];
              final data = roomDoc.data() as Map<String, dynamic>? ?? {};

              final membersRaw = (data["members"] ?? []) as List;
              final members =
                  membersRaw.map((e) => e.toString()).toList();

              if (members.length < 2) {
                return const SizedBox.shrink();
              }

              final otherId =
                  members.firstWhere((id) => id != currentUid);

              final lastMsg = data["lastMessage"]?.toString() ?? "";
              final lastFrom = data["lastSender"]?.toString() ?? "";

              final preview = lastMsg.isEmpty
                  ? "(No messages yet)"
                  : (lastFrom == currentUid ? "You: $lastMsg" : lastMsg);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(otherId)
                    .get(),

                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(title: Text("Loading user..."));
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};

                  final email =
                      userData["email"]?.toString() ?? "Unknown User";

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                      backgroundColor: Colors.orange,
                    ),

                    title: Text(email),
                    subtitle: Text(
                      preview,
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
