import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';
import 'view_profile_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final usersRef = FirebaseFirestore.instance.collection("users");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends & Requests"),
        backgroundColor: Colors.orange,
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: usersRef.doc(currentUid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final List incoming = data["incomingRequests"] ?? [];
          final List outgoing = data["outgoingRequests"] ?? [];
          final List friends = data["friends"] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // --------------------------------------------------
                // INCOMING FRIEND REQUESTS
                // --------------------------------------------------
                const Text(
                  "Incoming Friend Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (incoming.isEmpty)
                  const Text("No incoming requests.", style: TextStyle(color: Colors.grey)),

                ...incoming.map((uid) => _IncomingRequestTile(uid: uid)),

                const SizedBox(height: 30),

                // --------------------------------------------------
                // OUTGOING FRIEND REQUESTS
                // --------------------------------------------------
                const Text(
                  "Outgoing Friend Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (outgoing.isEmpty)
                  const Text("No outgoing requests.", style: TextStyle(color: Colors.grey)),

                ...outgoing.map((uid) => _OutgoingRequestTile(uid: uid)),

                const SizedBox(height: 30),

                // --------------------------------------------------
                // FRIENDS LIST
                // --------------------------------------------------
                const Text(
                  "Your Friends",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (friends.isEmpty)
                  const Text("You have no friends yet.", style: TextStyle(color: Colors.grey)),

                ...friends.map((uid) => _FriendTile(uid: uid)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================
//  INCOMING REQUEST WIDGET
// ===========================================================

class _IncomingRequestTile extends StatelessWidget {
  final String uid;

  const _IncomingRequestTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final usersRef = FirebaseFirestore.instance.collection("users");

    return FutureBuilder<DocumentSnapshot>(
      future: usersRef.doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final user =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final email = user["email"] ?? "Unknown";

        return Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(email),

            trailing: Wrap(
              spacing: 8,
              children: [
                // Accept
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () async {
                    await usersRef.doc(currentUid).update({
                      "incomingRequests": FieldValue.arrayRemove([uid]),
                      "friends": FieldValue.arrayUnion([uid]),
                    });
                    await usersRef.doc(uid).update({
                      "outgoingRequests": FieldValue.arrayRemove([currentUid]),
                      "friends": FieldValue.arrayUnion([currentUid]),
                    });
                  },
                ),

                // Decline
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () async {
                    await usersRef.doc(currentUid).update({
                      "incomingRequests": FieldValue.arrayRemove([uid]),
                    });
                    await usersRef.doc(uid).update({
                      "outgoingRequests":
                          FieldValue.arrayRemove([currentUid]),
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================
//  OUTGOING REQUEST WIDGET
// ===========================================================

class _OutgoingRequestTile extends StatelessWidget {
  final String uid;

  const _OutgoingRequestTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final usersRef = FirebaseFirestore.instance.collection("users");

    return FutureBuilder<DocumentSnapshot>(
      future: usersRef.doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final user =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final email = user["email"] ?? "Unknown";

        return Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(email),

            trailing: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.blueGrey),
              onPressed: () async {
                await usersRef.doc(currentUid).update({
                  "outgoingRequests": FieldValue.arrayRemove([uid]),
                });
                await usersRef.doc(uid).update({
                  "incomingRequests": FieldValue.arrayRemove([currentUid]),
                });
              },
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================
//  FRIEND TILE WIDGET
// ===========================================================

class _FriendTile extends StatelessWidget {
  final String uid;

  const _FriendTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final usersRef = FirebaseFirestore.instance.collection("users");

    return FutureBuilder<DocumentSnapshot>(
      future: usersRef.doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final user =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final email = user["email"] ?? "Unknown";

        return Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(email),

            subtitle: const Text("Friend"),

            trailing: Wrap(
              spacing: 8,
              children: [
                // Message
                IconButton(
                  icon: const Icon(Icons.message, color: Colors.orange),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherUserId: uid,
                          otherUserEmail: email,
                        ),
                      ),
                    );
                  },
                ),

                // Remove Friend
                IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  onPressed: () async {
                    await usersRef.doc(currentUid).update({
                      "friends": FieldValue.arrayRemove([uid]),
                    });
                    await usersRef.doc(uid).update({
                      "friends": FieldValue.arrayRemove([currentUid]),
                    });
                  },
                ),
              ],
            ),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewProfileScreen(userId: uid),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
