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
  late Future<Map<String, DocumentSnapshot>> _futureData;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _futureData = _loadProfile();
  }

  Future<Map<String, DocumentSnapshot>> _loadProfile() async {
    final fs = FirebaseFirestore.instance;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    final target = await fs.collection("users").doc(widget.userId).get();
    final current = await fs.collection("users").doc(currentUid).get();

    return {
      "target": target,
      "current": current,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _futureData = _loadProfile();
    });
  }

  // ============================================================
  // FRIEND SYSTEM (SAFE BATCH OPERATIONS)
  // ============================================================

  Future<void> _sendRequest(String currentUid) async {
    await _performAction(() async {
      final fs = FirebaseFirestore.instance;

      final batch = fs.batch();
      final me = fs.collection("users").doc(currentUid);
      final them = fs.collection("users").doc(widget.userId);

      batch.update(me, {
        "outgoingRequests": FieldValue.arrayUnion([widget.userId]),
      });
      batch.update(them, {
        "incomingRequests": FieldValue.arrayUnion([currentUid]),
      });

      await batch.commit();
    });
  }

  Future<void> _cancelRequest(String currentUid) async {
    await _performAction(() async {
      final fs = FirebaseFirestore.instance;

      final batch = fs.batch();
      final me = fs.collection("users").doc(currentUid);
      final them = fs.collection("users").doc(widget.userId);

      batch.update(me, {
        "outgoingRequests": FieldValue.arrayRemove([widget.userId]),
      });
      batch.update(them, {
        "incomingRequests": FieldValue.arrayRemove([currentUid]),
      });

      await batch.commit();
    });
  }

  Future<void> _acceptRequest(String currentUid) async {
    await _performAction(() async {
      final fs = FirebaseFirestore.instance;

      final batch = fs.batch();
      final me = fs.collection("users").doc(currentUid);
      final them = fs.collection("users").doc(widget.userId);

      batch.update(me, {
        "incomingRequests": FieldValue.arrayRemove([widget.userId]),
        "friends": FieldValue.arrayUnion([widget.userId]),
      });

      batch.update(them, {
        "outgoingRequests": FieldValue.arrayRemove([currentUid]),
        "friends": FieldValue.arrayUnion([currentUid]),
      });

      await batch.commit();
    });
  }

  Future<void> _declineRequest(String currentUid) async {
    await _performAction(() async {
      final fs = FirebaseFirestore.instance;

      final batch = fs.batch();
      final me = fs.collection("users").doc(currentUid);
      final them = fs.collection("users").doc(widget.userId);

      batch.update(me, {
        "incomingRequests": FieldValue.arrayRemove([widget.userId]),
      });

      batch.update(them, {
        "outgoingRequests": FieldValue.arrayRemove([currentUid]),
      });

      await batch.commit();
    });
  }

  Future<void> _removeFriend(String currentUid) async {
    await _performAction(() async {
      final fs = FirebaseFirestore.instance;

      final batch = fs.batch();
      final me = fs.collection("users").doc(currentUid);
      final them = fs.collection("users").doc(widget.userId);

      batch.update(me, {
        "friends": FieldValue.arrayRemove([widget.userId]),
      });
      batch.update(them, {
        "friends": FieldValue.arrayRemove([currentUid]),
      });

      await batch.commit();
    });
  }

  // Generic action wrapper
  Future<void> _performAction(Future<void> Function() action) async {
    setState(() => _isActionLoading = true);
    await action();
    setState(() => _isActionLoading = false);
    _refresh();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.orange,
      ),

      body: FutureBuilder<Map<String, DocumentSnapshot>>(
        future: _futureData,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final targetDoc = snap.data!["target"]!;
          final currentDoc = snap.data!["current"]!;

          if (!targetDoc.exists) {
            return const Center(child: Text("User not found."));
          }

          final target = targetDoc.data() as Map<String, dynamic>? ?? {};
          final current = currentDoc.data() as Map<String, dynamic>? ?? {};

          final email = target["email"] ?? "No Email";
          final bio = target["bio"] ?? "No bio available";
          final actualUid = target["uid"] ?? targetDoc.id;

          final friends =
              List<String>.from(current["friends"] ?? []);
          final incoming =
              List<String>.from(current["incomingRequests"] ?? []);
          final outgoing =
              List<String>.from(current["outgoingRequests"] ?? []);

          final bool isSelf = widget.userId == currentUid;
          final bool isFriend = friends.contains(widget.userId);
          final bool gotRequest = incoming.contains(widget.userId);
          final bool sentRequest = outgoing.contains(widget.userId);

          // ---------------------------------------------------------------
          // ACTION BUTTONS LOGIC
          // ---------------------------------------------------------------
          Widget action = const SizedBox.shrink();

          if (!isSelf) {
            if (isFriend) {
              action = Column(
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
                                  otherUserEmail: email,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.message),
                    label: const Text("Message"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _removeFriend(currentUid),
                    icon: const Icon(Icons.person_remove),
                    label: const Text("Remove Friend"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                  ),
                ],
              );
            } else if (gotRequest) {
              action = Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _acceptRequest(currentUid),
                    icon: const Icon(Icons.check),
                    label: const Text("Accept Request"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _declineRequest(currentUid),
                    icon: const Icon(Icons.close),
                    label: const Text("Decline"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey),
                  ),
                ],
              );
            } else if (sentRequest) {
              action = ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _cancelRequest(currentUid),
                icon: const Icon(Icons.hourglass_top),
                label: const Text("Cancel Request"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey),
              );
            } else {
              action = ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _sendRequest(currentUid),
                icon: const Icon(Icons.person_add),
                label: const Text("Add Friend"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange),
              );
            }
          }

          // ---------------------------------------------------------------
          // UI LAYOUT
          // ---------------------------------------------------------------
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
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
                    email,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    "User ID:\n$actualUid",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black54),
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
                      bio,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (isSelf)
                    const Text(
                      "This is your own profile.",
                      style: TextStyle(color: Colors.grey),
                    ),

                  if (!isSelf) action,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
