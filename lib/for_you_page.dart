// lib/for_you_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'post_card.dart';

class ForYouPage extends StatelessWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData =
            userSnap.data!.data() as Map<String, dynamic>? ?? {};

        // ✅ Friends + Following (NOT followers)
        final Set<String> ids = {
          uid,
          ...List<String>.from(userData['friends'] ?? []),
          ...List<String>.from(userData['outgoingRequests'] ?? []),
        };

        // Firestore whereIn limit = 10
        final List<String> limited = ids.take(10).toList();

        if (limited.isEmpty) {
          return const Center(
            child: Text('No friends or following yet.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('authorId', whereIn: limited)
                .orderBy('createdAt', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                // ❌ no const here
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
