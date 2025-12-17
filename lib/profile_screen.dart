import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class ProfileScreen extends StatefulWidget {
  static const String routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _bioController = TextEditingController();
  bool _bioDirty = false;

  Future<void> _pickAndUploadProfilePhoto(
    BuildContext context,
    User user,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('${user.uid}.jpg');

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoUrl': downloadUrl});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated')),
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Not logged in',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ),
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

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final bool isOnline = data['isOnline'] ?? false;
          final Timestamp? lastSeen = data['lastSeen'];
          final String? photoUrl = data['photoUrl'];
          final String? bio = data['bio'];

          if (!_bioDirty) {
            _bioController.text = bio ?? '';
          }

          return Column(
            children: [
              const SizedBox(height: 16),

              /// PROFILE PHOTO
              Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () =>
                          _pickAndUploadProfilePhoto(context, user),
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

              /// BIO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bio',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tell us about yourself',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() => _bioDirty = true);
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: !_bioDirty
                          ? null
                          : () async {
                              await userDoc.update({
                                'bio': _bioController.text.trim(),
                              });
                              setState(() => _bioDirty = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Bio saved')),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      child: const Text(
                        'Save Bio',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
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

              /// DARK MODE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListTile(
                  leading: const Icon(Icons.light_mode, color: Colors.orange),
                  title: const Text('Dark Mode'),
                  trailing: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (_, currentMode, __) {
                      return Switch(
                        value: currentMode == ThemeMode.dark,
                        onChanged: (val) async {
                          themeNotifier.value =
                              val ? ThemeMode.dark : ThemeMode.light;
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('isDarkMode', val);
                        },
                      );
                    },
                  ),
                ),
              ),

              const Divider(),

              /// ACTIONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _profileButton(
                      icon: Icons.people,
                      label: 'Friends List',
                      onTap: () =>
                          Navigator.pushNamed(context, '/friends'),
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
                              content: Text(
                                  'Password reset email sent'),
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
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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
                        child:
                            Text('You have not posted anything yet.'),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data()
                            as Map<String, dynamic>? ??
                            {};
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
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
