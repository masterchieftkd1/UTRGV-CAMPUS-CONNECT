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
                  room.data() as Map<String, dynamic>? ?? <String, dynamic>{};

              final List<dynamic> participants =
                  data['participants'] ?? <dynamic>[];
              if (participants.length != 2) {
                return const SizedBox.shrink();
              }

              // Pick the other user's id
              final otherUserId = participants
                  .firstWhere((id) => id != currentUid)
                  .toString();

              final lastMessage = data['lastMessage'] as String? ?? '';
              final Timestamp? ts =
                  data['lastMessageTime'] as Timestamp?;
              final DateTime? time = ts?.toDate();

              final lastFrom = data['lastMessageFrom'] as String? ?? '';
              final List<dynamic> seenByDynamic =
                  data['seenBy'] ?? <dynamic>[];
              final seenBy =
                  seenByDynamic.map((e) => e.toString()).toList();

              final bool isLastFromMe = lastFrom == currentUid;
              final bool hasSeenLast = seenBy.contains(currentUid);

              String subtitle = lastMessage.isEmpty ? "No messages yet" : lastMessage;
              if (!isLastFromMe && !hasSeenLast && lastMessage.isNotEmpty) {
                subtitle = "New: $lastMessage";
              }

              String timeString = "";
              if (time != null) {
                final now = DateTime.now();
                if (now.difference(time).inDays == 0) {
                  // Same day -> HH:mm
                  timeString =
                      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                } else {
                  // Show MM/DD
                  timeString = "${time.month}/${time.day}";
                }
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnap) {
                  String email = "Unknown user";
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final udata = userSnap.data!.data()
                        as Map<String, dynamic>? ?? <String, dynamic>{};
                    email = udata['email'] ?? email;
                  }

                  final bool showUnreadDot =
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
                          ),
                      ],
                    ),
                    title: Text(email),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      timeString,
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
