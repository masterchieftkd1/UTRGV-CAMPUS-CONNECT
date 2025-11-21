import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _auth = FirebaseAuth.instance;
  bool _loadingAction = false;

  User? get _user => _auth.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends & Requests"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? <String, dynamic>{};

          final List<String> friends =
              List<String>.from(data['friends'] ?? []);
          final List<String> incoming =
              List<String>.from(data['incomingRequests'] ?? []);
          final List<String> outgoing =
              List<String>.from(data['outgoingRequests'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Friends",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (friends.isEmpty)
                const Text("You have no friends yet."),
              for (final uid in friends)
                _UserTileFromId(
                  uid: uid,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/viewProfile',
                      arguments: uid,
                    );
                  },
                  trailing: TextButton.icon(
                    onPressed: _loadingAction
                        ? null
                        : () => _removeFriend(uid),
                    icon: const Icon(Icons.person_remove),
                    label: const Text("Remove"),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                "Incoming Requests",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (incoming.isEmpty)
                const Text("No incoming friend requests."),
              for (final uid in incoming)
                _UserTileFromId(
                  uid: uid,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/viewProfile',
                      arguments: uid,
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _loadingAction
                            ? null
                            : () => _acceptFriendRequest(uid),
                        child: const Text("Accept"),
                      ),
                      TextButton(
                        onPressed: _loadingAction
                            ? null
                            : () => _declineFriendRequest(uid),
                        child: const Text("Decline"),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                "Outgoing Requests",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (outgoing.isEmpty)
                const Text("No outgoing friend requests."),
              for (final uid in outgoing)
                _UserTileFromId(
                  uid: uid,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/viewProfile',
                      arguments: uid,
                    );
                  },
                  trailing: TextButton(
                    onPressed: _loadingAction
                        ? null
                        : () => _cancelFriendRequest(uid),
                    child: const Text("Cancel"),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Future<void> _acceptFriendRequest(String fromUid) async {
    if (_user == null) return;
    setState(() => _loadingAction = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    final currentRef = fs.collection('users').doc(_user!.uid);
    final otherRef = fs.collection('users').doc(fromUid);

    batch.update(currentRef, {
      'incomingRequests': FieldValue.arrayRemove([fromUid]),
      'friends': FieldValue.arrayUnion([fromUid]),
    });

    batch.update(otherRef, {
      'outgoingRequests': FieldValue.arrayRemove([_user!.uid]),
      'friends': FieldValue.arrayUnion([_user!.uid]),
    });

    await batch.commit();
    setState(() => _loadingAction = false);
  }

  Future<void> _declineFriendRequest(String fromUid) async {
    if (_user == null) return;
    setState(() => _loadingAction = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    final currentRef = fs.collection('users').doc(_user!.uid);
    final otherRef = fs.collection('users').doc(fromUid);

    batch.update(currentRef, {
      'incomingRequests': FieldValue.arrayRemove([fromUid]),
    });

    batch.update(otherRef, {
      'outgoingRequests': FieldValue.arrayRemove([_user!.uid]),
    });

    await batch.commit();
    setState(() => _loadingAction = false);
  }

  Future<void> _cancelFriendRequest(String toUid) async {
    if (_user == null) return;
    setState(() => _loadingAction = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    final currentRef = fs.collection('users').doc(_user!.uid);
    final otherRef = fs.collection('users').doc(toUid);

    batch.update(currentRef, {
      'outgoingRequests': FieldValue.arrayRemove([toUid]),
    });

    batch.update(otherRef, {
      'incomingRequests': FieldValue.arrayRemove([_user!.uid]),
    });

    await batch.commit();
    setState(() => _loadingAction = false);
  }

  Future<void> _removeFriend(String friendUid) async {
    if (_user == null) return;
    setState(() => _loadingAction = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    final currentRef = fs.collection('users').doc(_user!.uid);
    final otherRef = fs.collection('users').doc(friendUid);

    batch.update(currentRef, {
      'friends': FieldValue.arrayRemove([friendUid]),
    });

    batch.update(otherRef, {
      'friends': FieldValue.arrayRemove([_user!.uid]),
    });

    await batch.commit();
    setState(() => _loadingAction = false);
  }
}

class _UserTileFromId extends StatelessWidget {
  final String uid;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _UserTileFromId({
    super.key,
    required this.uid,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            title: Text("Loading..."),
          );
        }

        if (!snapshot.data!.exists) {
          return const ListTile(
            title: Text("Unknown user"),
          );
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? <String, dynamic>{};
        final email = data['email'] ?? 'No Email';

        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(email),
          onTap: onTap,
          trailing: trailing,
        );
      },
    );
  }
}
