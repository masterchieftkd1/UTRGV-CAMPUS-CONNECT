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

  Future<void> _removeFriend(String currentUid) async {
    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    final currentRef = fs.collection('users').doc(currentUid);
    final targetRef = fs.collection('users').doc(widget.userId);

    batch.update(currentRef, {
      'friends': FieldValue.arrayRemove([widget.userId]),
    });

    batch.update(targetRef, {
      'friends': FieldValue.arrayRemove([currentUid]),
    });

    await batch.commit();
    _refresh();
  }

  Future<void> _blockUser(String currentUid) async {
    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    final currentRef = fs.collection('users').doc(currentUid);
    final targetRef = fs.collection('users').doc(widget.userId);

    batch.update(currentRef, {
      'blockedUsers': FieldValue.arrayUnion([widget.userId]),
      'friends': FieldValue.arrayRemove([widget.userId]),
      'incomingRequests': FieldValue.arrayRemove([widget.userId]),
      'outgoingRequests': FieldValue.arrayRemove([widget.userId]),
    });

    batch.update(targetRef, {
      'friends': FieldValue.arrayRemove([currentUid]),
      'incomingRequests': FieldValue.arrayRemove([currentUid]),
      'outgoingRequests': FieldValue.arrayRemove([currentUid]),
    });

    await batch.commit();

    if (mounted) {
      Navigator.pop(context);
    }
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
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<Map<String, DocumentSnapshot>>(
        future: _profileFuture,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("User not found."));
          }

          final targetDoc = snapshot.data!['target']!;
          final currentDoc = snapshot.data!['current']!;

          final targetData =
              targetDoc.data() as Map<String, dynamic>? ?? {};
          final currentData =
              currentDoc.data() as Map<String, dynamic>? ?? {};

          final email = targetData['email'] ?? 'No Email';
          final bio = targetData['bio'] ?? 'No bio';
          final bool isOnline = targetData['isOnline'] ?? false;
          final Timestamp? lastSeen = targetData['lastSeen'];

          final List myFriends =
              List.from(currentData['friends'] ?? []);
          final bool isSelf = widget.userId == currentUid;
          final bool isFriend = myFriends.contains(widget.userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.person,
                      size: 70, color: Colors.white),
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

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(bio),
                ),

                const SizedBox(height: 30),

                if (!isSelf && isFriend)
                  ElevatedButton.icon(
                    onPressed: () => _removeFriend(currentUid!),
                    icon: const Icon(Icons.person_remove),
                    label: const Text("Remove Friend"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),

                if (!isSelf)
                  const SizedBox(height: 10),

                if (!isSelf)
                  ElevatedButton.icon(
                    onPressed: () => _blockUser(currentUid!),
                    icon: const Icon(Icons.block),
                    label: const Text("Block User"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),

                if (!isSelf && isFriend)
                  const SizedBox(height: 10),

                if (!isSelf && isFriend)
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
              ],
            ),
          );
        },
      ),
    );
  }
}
