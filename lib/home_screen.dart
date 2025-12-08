// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔧 FIXED — correct import path!
import '../auth_service.dart';

import 'create_post_screen.dart';
import 'profile_screen.dart';
import 'comments_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Connect Feed'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.pushNamed(context, ProfileScreen.routeName);
            },
          ),

          // 🔧 FIXED — correct logout call
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),

      // 🔥 FEED
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet.\nTap the + button to share something!',
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data =
                  doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

              final postId = doc.id;
              final text = (data['text'] ?? '').toString();
              final authorEmail = (data['authorEmail'] ?? 'Unknown').toString();
              final authorId = (data['authorId'] ?? '').toString();
              final likeCount = (data['likeCount'] ?? 0) as int;
              final commentCount = (data['commentCount'] ?? 0) as int;

              final likedByRaw = (data['likedBy'] ?? <dynamic>[]) as List;
              final likedBy = likedByRaw.map((e) => e.toString()).toList();

              final bool isLiked = uid != null && likedBy.contains(uid);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // AUTHOR INFO
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authorEmail,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(text),
                      const SizedBox(height: 8),

                      // LIKE + COMMENT ROW
                      Row(
                        children: [
                          // ❤️ LIKE BUTTON
                          IconButton(
                            icon: Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                            onPressed: uid == null
                                ? null
                                : () => _toggleLike(
                                      postId: postId,
                                      currentUid: uid,
                                      isLiked: isLiked,
                                    ),
                          ),
                          Text(likeCount.toString()),

                          const SizedBox(width: 16),

                          // 💬 COMMENTS BUTTON
                          IconButton(
                            icon: const Icon(Icons.comment),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                CommentsScreen.routeName,
                                arguments: CommentsScreenArgs(
                                  postId: postId,
                                  postText: text,
                                  authorEmail: authorEmail,
                                ),
                              );
                            },
                          ),
                          Text(commentCount.toString()),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // ➕ CREATE NEW POST
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// LIKE / UNLIKE POST
Future<void> _toggleLike({
  required String postId,
  required String currentUid,
  required bool isLiked,
}) async {
  final ref = FirebaseFirestore.instance.collection('posts').doc(postId);

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final snap = await txn.get(ref);
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final rawLikedBy = (data['likedBy'] ?? <dynamic>[]) as List;

    final List<String> likedBy = rawLikedBy.map((e) => e.toString()).toList();

    if (isLiked) {
      likedBy.remove(currentUid);
      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      if (!likedBy.contains(currentUid)) {
        likedBy.add(currentUid);
      }
      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': FieldValue.increment(1),
      });
    }
  });
}
