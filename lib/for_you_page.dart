import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'post_card.dart';

class ForYouPage extends StatelessWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }

    final uid = user.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!userSnap.hasData || userSnap.data == null) {
          return const Center(child: Text('Failed to load user data.'));
        }

        final userData =
            userSnap.data!.data() as Map<String, dynamic>? ?? {};

        // Friends + following + self
        final Set<String> ids = {
          uid,
          ...List<String>.from(userData['friends'] ?? []),
          ...List<String>.from(userData['outgoingRequests'] ?? []),
        };

        // Firestore whereIn limit = 10
        final List<String> limited = ids.take(10).toList();

        if (limited.isEmpty) {
          return const Center(child: Text('No friends or following yet.'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('authorId', whereIn: limited)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 250),
                    Center(
                      child: Text(
                        'No posts from friends or following yet.',
                      ),
                    ),
                  ],
                );
              }

              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aTime = a['createdAt'] as Timestamp?;
                  final bTime = b['createdAt'] as Timestamp?;
                  return (bTime?.millisecondsSinceEpoch ?? 0)
                      .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
                });

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data =
                      doc.data() as Map<String, dynamic>? ?? {};
                  return PostCard(
                    postId: doc.id,
                    data: data,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
