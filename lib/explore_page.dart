// lib/explore_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_card.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          // ❌ NO const here
          return ListView(
            children: const [
              SizedBox(height: 250),
              Center(child: Text('No posts yet.')),
            ],
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return PostCard(postId: doc.id, data: data);
          },
        );
      },
    );
  }
}
