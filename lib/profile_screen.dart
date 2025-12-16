import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  static const String routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final bool isOnline = data['isOnline'] ?? false;
          final Timestamp? lastSeen = data['lastSeen'];

          return Column(
            children: [
              const SizedBox(height: 16),

              /// PROFILE AVATAR
              Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.person, size: 50),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () {
                        // hook for profile picture upload
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// EMAIL
              Text(
                user.email ?? 'Unknown email',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              /// ONLINE STATUS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline
                        ? 'Online'
                        : lastSeen == null
                            ? 'Offline'
                            : 'Last seen just now',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),

              /// ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _profileButton(
                      icon: Icons.people,
                      label: 'Friends List',
                      onTap: () {
                        Navigator.pushNamed(context, '/friends');
                      },
                    ),
                    _profileButton(
                      icon: Icons.lock,
                      label: 'Change Password',
                      onTap: () async {
                        if (user.email != null) {
                          await FirebaseAuth.instance
                              .sendPasswordResetEmail(
                            email: user.email!,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Password reset email sent'),
                            ),
                          );
                        }
                      },
                    ),
                    _profileButton(
                      icon: Icons.delete,
                      label: 'Delete Account',
                      color: Colors.red,
                      onTap: () async {
                        await userDoc.delete();
                        await user.delete();
                        Navigator.pushReplacementNamed(
                            context, '/login');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),

              /// POSTS
              const Padding(
                padding: EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'My Posts',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: postsQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'You have not posted anything yet.',
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data()
                            as Map<String, dynamic>? ?? {};
                        final text = data['text'] ?? '';

                        return ListTile(
                          leading: const Icon(Icons.article),
                          title: Text(text),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.orange),
      title: Text(
        label,
        style: TextStyle(color: color),
      ),
      onTap: onTap,
    );
  }
}
