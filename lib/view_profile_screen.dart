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

    return {
      'target': targetDoc,
      'current': currentDoc,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }

  Future<void> _sendFriendRequest(String currentUid) async {
    setState(() => _isActionLoading = true);
    final fs = FirebaseFirestore.instance;

    final batch = fs.batch();
    final currentRef = fs.collection('users').doc(currentUid);
    final targetRef = fs.collection('users').doc(widget.userId);

    // You send request → outgoingRequests, they receive → incomingRequests
    batch.update(currentRef, {
      'outgoingRequests': FieldValue.arrayUnion([widget.userId]),
    });
    batch.update(targetRef, {
      'incomingRequests': FieldValue.arrayUnion([currentUid]),
    });

    await batch.commit();
    setState(() => _isActionLoading = false);
    _refresh();
  }

  Future<void> _cancelFriendRequest(String currentUid) async {
    setState(() => _isActionLoading = true);
    final fs = FirebaseFirestore.instance;

    final batch = fs.batch();
    final currentRef = fs.collection('users').doc(currentUid);
    final targetRef = fs.collection('users').doc(widget.userId);

    batch.update(currentRef, {
      'outgoingRequests': FieldValue.arrayRemove([widget.userId]),
    });
    batch.update(targetRef, {
      'incomingRequests': FieldValue.arrayRemove([currentUid]),
    });

    await batch.commit();
    setState(() => _isActionLoading = false);
    _refresh();
  }

  Future<void> _acceptFriendRequest(String currentUid) async {
    setState(() => _isActionLoading = true);
    final fs = FirebaseFirestore.instance;

    final batch = fs.batch();
    final currentRef = fs.collection('users').doc(currentUid);
    final targetRef = fs.collection('users').doc(widget.userId);

    // Move from request → friend for both sides
    batch.update(currentRef, {
      'incomingRequests': FieldValue.arrayRemove([widget.userId]),
      'friends': FieldValue.arrayUnion([widget.userId]),
    });
    batch.update(targetRef, {
      'outgoingRequests': FieldValue.arrayRemove([currentUid]),
      'friends': FieldValue.arrayUnion([currentUid]),
    });

    await batch.commit();
    setState(() => _isActionLoading = false);
    _refresh();
  }

  Future<void> _declineFriendRequest(String currentUid) async {
    setState(() => _isActionLoading = true);
    final fs = FirebaseFirestore.instance;

    final batch = fs.batch();
    final currentRef = fs.collection('users').doc(currentUid);
    final targetRef = fs.collection('users').doc(widget.userId);

    batch.update(currentRef, {
      'incomingRequests': FieldValue.arrayRemove([widget.userId]),
    });
    batch.update(targetRef, {
      'outgoingRequests': FieldValue.arrayRemove([currentUid]),
    });

    await batch.commit();
    setState(() => _isActionLoading = false);
    _refresh();
  }

  Future<void> _removeFriend(String currentUid) async {
    setState(() => _isActionLoading = true);
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
    setState(() => _isActionLoading = false);
    _refresh();
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

          if (!targetDoc.exists) {
            return const Center(child: Text("User not found."));
          }

          final targetData =
              targetDoc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
          final currentData =
              currentDoc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

          final email = targetData['email'] ?? 'No Email';
          final bio = targetData['bio'] ?? 'No bio available.';
          final actualUid = targetData['uid'] ?? targetDoc.id;

          // Relationship arrays
          final List<String> myFriends =
              List<String>.from(currentData['friends'] ?? []);
          final List<String> myIncoming =
              List<String>.from(currentData['incomingRequests'] ?? []);
          final List<String> myOutgoing =
              List<String>.from(currentData['outgoingRequests'] ?? []);

          // Target user's relationship data – for counts on THEIR profile
          final List<String> targetFriends =
              List<String>.from(targetData['friends'] ?? []);
          final List<String> targetIncoming =
              List<String>.from(targetData['incomingRequests'] ?? []);
          final List<String> targetOutgoing =
              List<String>.from(targetData['outgoingRequests'] ?? []);

          // Counts for target user
          final Set<String> targetFriendsSet =
              targetFriends.map((e) => e.toString()).toSet();

          final int targetFriendsCount = targetFriendsSet.length;
          final int targetFollowersCount = targetIncoming
              .map((e) => e.toString())
              .where((id) => !targetFriendsSet.contains(id))
              .length;
          final int targetFollowingCount = targetOutgoing
              .map((e) => e.toString())
              .where((id) => !targetFriendsSet.contains(id))
              .length;

          final bool isSelf = widget.userId == currentUid;
          final bool isFriend = myFriends.contains(widget.userId);
          final bool requestReceived = myIncoming.contains(widget.userId);
          final bool requestSent = myOutgoing.contains(widget.userId);

          Widget actionArea = const SizedBox.shrink();

          if (!isSelf && currentUid != null) {
            if (isFriend) {
              // Already friends
              actionArea = Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: widget.userId,
                                  otherUserEmail: email.toString(),
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
                    onPressed: _isActionLoading
                        ? null
                        : () => _removeFriend(currentUid),
                    icon: const Icon(Icons.person_remove),
                    label: const Text("Remove Friend"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              );
            } else if (requestReceived) {
              // They requested you
              actionArea = Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _acceptFriendRequest(currentUid),
                    icon: const Icon(Icons.check),
                    label: const Text("Accept Friend Request"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _declineFriendRequest(currentUid),
                    icon: const Icon(Icons.close),
                    label: const Text("Decline"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              );
            } else if (requestSent) {
              // You requested them
              actionArea = ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _cancelFriendRequest(currentUid),
                icon: const Icon(Icons.hourglass_top),
                label: const Text("Cancel Friend Request"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  minimumSize: const Size(double.infinity, 45),
                ),
              );
            } else {
              // No relation yet → send friend request (and logically you're "following" them now)
              actionArea = ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _sendFriendRequest(currentUid),
                icon: const Icon(Icons.person_add),
                label: const Text("Add Friend"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 45),
                ),
              );
            }
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.orange,
                    child: const Icon(
                      Icons.person,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    email.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "User ID:\n$actualUid",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔥 Friends / Following / Followers row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem("Friends", targetFriendsCount),
                      _statItem("Following", targetFollowingCount),
                      _statItem("Followers", targetFollowersCount),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bio.toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (isSelf)
                    const Text(
                      "This is your own profile.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  if (!isSelf) actionArea,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
