import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'comments_screen.dart';
import 'view_profile_screen.dart';

class PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;

  const PostCard({
    super.key,
    required this.postId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final currentUid = user.uid;

    final authorId = (data['authorId'] ?? '').toString();
    final authorEmail = (data['authorEmail'] ?? 'Unknown').toString();
    final text = (data['text'] ?? '').toString();
    final imageUrl = data['imageUrl']?.toString();

    final likeCount = (data['likeCount'] ?? 0) as int;
    final commentCount = (data['commentCount'] ?? 0) as int;

    final List likedBy = (data['likedBy'] ?? <dynamic>[]) as List;
    final bool isLiked = likedBy.contains(currentUid);
    final bool isMine = authorId == currentUid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: authorId.isEmpty
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ViewProfileScreen(userId: authorId),
                              ),
                            ),
                    child: Text(
                      authorEmail,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (isMine)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete post?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (ok == true) {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .delete();
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (text.isNotEmpty)
              Text(text, style: const TextStyle(fontSize: 16)),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FullScreenImage(url: imageUrl),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, w, p) {
                        if (p == null) return w;
                        return const Center(
                            child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Text('Image failed to load'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => _toggleLike(
                    postId: postId,
                    currentUid: currentUid,
                    isLiked: isLiked,
                  ),
                ),
                Text(likeCount.toString()),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommentsScreen(postId: postId),
                    ),
                  ),
                ),
                Text(commentCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    final List likedBy = (data['likedBy'] ?? <dynamic>[]) as List;

    if (isLiked) {
      likedBy.remove(currentUid);
      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      likedBy.add(currentUid);
      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': FieldValue.increment(1),
      });
    }
  });
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            const Text('Photo', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}
