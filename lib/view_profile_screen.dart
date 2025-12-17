import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  final String userId;
  const ViewProfileScreen({super.key, required this.userId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<Map<String, DocumentSnapshot>> _profileFuture;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
  }

  Future<Map<String, DocumentSnapshot>> _loadProfileData() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;

    final targetDoc = await fs.collection('users').doc(widget.userId).get();
    final currentDoc = await fs.collection('users').doc(currentUid).get();

    return {'target': targetDoc, 'current': currentDoc};
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }

  Future<void> _addFriend(String currentUid) async {
    setState(() => _isActionLoading = true);
    final fs = FirebaseFirestore.instance;

    await fs.collection('users').doc(currentUid).update({
      'outgoingRequests': FieldValue.arrayUnion([widget.userId]),
    });

    await fs.collection('users').doc(widget.userId).update({
      'incomingRequests': FieldValue.arrayUnion([currentUid]),
    });

    setState(() => _isActionLoading = false);
    _refresh();
  }

  Future<void> _removeFriend(String currentUid) async {
    setState(() => _isActionLoading = true);
    final fs = FirebaseFirestore.instance;

    final batch = fs.batch();
    batch.update(fs.collection('users').doc(currentUid), {
      'friends': FieldValue.arrayRemove([widget.userId]),
    });
    batch.update(fs.collection('users').doc(widget.userId), {
      'friends': FieldValue.arrayRemove([currentUid]),
    });

    await batch.commit();
    setState(() => _isActionLoading = false);
    _refresh();
  }

  Future<void> _blockUser(String currentUid) async {
    final fs = FirebaseFirestore.instance;

    await fs.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayUnion([widget.userId]),
      'friends': FieldValue.arrayRemove([widget.userId]),
      'incomingRequests': FieldValue.arrayRemove([widget.userId]),
      'outgoingRequests': FieldValue.arrayRemove([widget.userId]),
    });

    if (mounted) Navigator.pop(context);
  }

  String _lastSeenText(bool isOnline, Timestamp? lastSeen) {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final diff = DateTime.now().difference(lastSeen.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<Map<String, DocumentSnapshot?>>(
        future: _profileFuture,
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final targetSnapshot = snapshot.data?['target'];
          final currentSnapshot = snapshot.data?['current'];

          if (targetSnapshot == null || !targetSnapshot.exists) {
            return const Center(
              child: Text(
                'User not found or has deleted their account.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          if (currentSnapshot == null || !currentSnapshot.exists) {
            return const Center(
              child: Text(
                'Something went wrong. Try again later.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final targetData = targetSnapshot.data() as Map<String, dynamic>;
          final currentData = currentSnapshot.data() as Map<String, dynamic>;

          final email = targetData['email'] ?? '';
          final bio = targetData['bio'] ?? '';
          final bool isOnline = targetData['isOnline'] ?? false;
          final Timestamp? lastSeen = targetData['lastSeen'];

          final List friends = List.from(currentData['friends'] ?? []);
          final bool isSelf = widget.userId == currentUid;
          final bool isFriend = friends.contains(widget.userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.person, size: 70, color: Colors.white),
                ),
                const SizedBox(height: 20),

                Text(email,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle,
                        size: 10,
                        color: isOnline ? Colors.green : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      _lastSeenText(isOnline, lastSeen),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// 🌟 BIO DISPLAY
                if (bio.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bio,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                const SizedBox(height: 30),

                if (!isSelf && !isFriend)
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _addFriend(currentUid!),
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Friend"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),

                if (!isSelf && isFriend) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: widget.userId,
                            otherUserEmail: email,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text("Message"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _removeFriend(currentUid!),
                    icon: const Icon(Icons.person_remove),
                    label: const Text("Remove Friend"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],

                if (!isSelf) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _blockUser(currentUid!),
                    icon: const Icon(Icons.block),
                    label: const Text("Block User"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
