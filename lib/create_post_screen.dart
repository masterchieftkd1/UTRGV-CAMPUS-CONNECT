import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  File? _image;
  bool _posting = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80, // keeps uploads smaller (faster)
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _image = File(picked.path));
  }

  Future<void> _submitPost() async {
    if (_posting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _textController.text.trim();

    if (text.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post cannot be empty')),
      );
      return;
    }

    setState(() => _posting = true);

    try {
      String? imageUrl;

      // upload image if any
      if (_image != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
        final ref = FirebaseStorage.instance.ref().child('post_images/$fileName');

        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'text': text,
        'imageUrl': imageUrl,
        'authorId': user.uid,
        'authorEmail': user.email ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'likedBy': <String>[],
        'commentCount': 0,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What’s happening on campus?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            if (_image != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _image!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _posting ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.image, color: Colors.white),
                  label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _posting ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('Camera', style: TextStyle(color: Colors.white)),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _posting ? null : _submitPost,
                  child: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
