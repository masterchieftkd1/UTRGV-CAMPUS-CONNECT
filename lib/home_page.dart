import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'search_users_screen.dart';
import 'messages_inbox_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'comments_screen.dart';
import 'view_profile_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UTRGV Campus Connect'),
        backgroundColor: Colors.orange,
        actions: [
          // 🔍 Search users
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SearchUsersScreen(),
                ),
              );
            },
          ),

          // 💬 Messages inbox
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessagesInboxScreen(),
                ),
              );
            },
          ),

          // 👤 Profile
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),

          // 🚪 Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      // 🔥 Main social feed
      body: const _Feed(),

      // ➕ Create new post
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostScreen(),
            ),
          );
        },
      ),
    );
  }
}

/// FEED LIST – shows all posts in reverse chronological order
class _Feed extends StatelessWidget {
  const _Feed({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No posts yet.\nTap the + button to share something with campus!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final postId = doc.id;
            final text = (data['text'] ?? '').toString();
            final authorEmail = (data['authorEmail'] ?? 'Unknown').toString();
            final authorId = (data['authorId'] ?? '').toString();
            final likeCount = (data['likeCount'] ?? 0) as int;
            final commentCount = (data['commentCount'] ?? 0) as int;

            final likedByRaw = data['likedBy'] ?? <dynamic>[];
            final List<String> likedBy = List<String>.from(
              (likedByRaw as List).map((e) => e.toString()),
            );

            final bool isLiked =
                currentUid != null && likedBy.contains(currentUid);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row with avatar + email – tap to open profile
                    GestureDetector(
                      onTap: () {
                        if (authorId.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ViewProfileScreen(userId: authorId),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.person, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            authorEmail,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Post text
                    Text(
                      text,
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 8),

                    // Like + comment row
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                          onPressed: currentUid == null
                              ? null
                              : () => _toggleLike(
                                    postId: postId,
                                    isLiked: isLiked,
                                    currentUid: currentUid,
                                  ),
                        ),
                        Text(likeCount.toString()),

                        const SizedBox(width: 16),

                        IconButton(
                          icon: const Icon(Icons.comment),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommentsScreen(postId: postId),
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
    );
  }
}

/// Toggle like / unlike on a post
Future<void> _toggleLike({
  required String postId,
  required String currentUid,
  required bool isLiked,
}) async {
  final postRef =
      FirebaseFirestore.instance.collection('posts').doc(postId);

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final snap = await txn.get(postRef);
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final likedByRaw = data['likedBy'] ?? <dynamic>[];

    final List<String> likedBy = List<String>.from(
      (likedByRaw as List).map((e) => e.toString()),
    );

    if (isLiked) {
      // Unlike
      likedBy.remove(currentUid);
      txn.update(postRef, {
        'likedBy': likedBy,
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      // Like
      likedBy.add(currentUid);
      txn.update(postRef, {
        'likedBy': likedBy,
        'likeCount': FieldValue.increment(1),
      });
    }
  });
}
