// lib/chat_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserEmail;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();
  final _picker = ImagePicker();
  Timer? _typingTimer;

  String get _myUid => _auth.currentUser!.uid;

  String get _chatId {
    final ids = [_myUid, widget.otherUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _ensureRoom();
    _markSeen();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _setTyping(false);
    _messageController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // CHAT ROOM SETUP
  // --------------------------------------------------
  Future<void> _ensureRoom() async {
    final ref =
        FirebaseFirestore.instance.collection('chatRooms').doc(_chatId);

    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [_myUid, widget.otherUserId],
        'typing': {
          _myUid: false,
          widget.otherUserId: false,
        },
        'lastMessage': '',
        'lastMessageFrom': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'seenBy': [],
      });
    }
  }

  // --------------------------------------------------
  // TYPING
  // --------------------------------------------------
  Future<void> _setTyping(bool value) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(_chatId)
        .set({
      'typing': {_myUid: value},
    }, SetOptions(merge: true));
  }

  void _onTyping(String text) {
    _typingTimer?.cancel();
    final isTyping = text.trim().isNotEmpty;
    _setTyping(isTyping);

    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _setTyping(false);
      });
    }
  }

  // --------------------------------------------------
  // SEND TEXT MESSAGE
  // --------------------------------------------------
  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _setTyping(false);

    await _sendMessage(
      text: text,
      imageUrl: null,
    );
  }

  // --------------------------------------------------
  // SEND IMAGE MESSAGE
  // --------------------------------------------------
  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final ref = FirebaseStorage.instance
        .ref('chat_images/$_chatId/${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _sendMessage(
      text: '',
      imageUrl: url,
    );
  }

  // --------------------------------------------------
  // COMMON SEND
  // --------------------------------------------------
  Future<void> _sendMessage({
    required String text,
    required String? imageUrl,
  }) async {
    final roomRef =
        FirebaseFirestore.instance.collection('chatRooms').doc(_chatId);

    final msgRef = await roomRef.collection('messages').add({
      'fromId': _myUid,
      'toId': widget.otherUserId,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'seen': false,
    });

    await roomRef.set({
      'lastMessage': imageUrl != null ? '📷 Image' : text,
      'lastMessageFrom': _myUid,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageId': msgRef.id,
      'seenBy': [_myUid],
    }, SetOptions(merge: true));
  }

  // --------------------------------------------------
  // READ RECEIPTS
  // --------------------------------------------------
  Future<void> _markSeen() async {
    final roomRef =
        FirebaseFirestore.instance.collection('chatRooms').doc(_chatId);

    final messages = await roomRef
        .collection('messages')
        .where('toId', isEqualTo: _myUid)
        .where('seen', isEqualTo: false)
        .get();

    for (final doc in messages.docs) {
      doc.reference.update({'seen': true});
    }

    await roomRef.set({
      'seenBy': FieldValue.arrayUnion([_myUid]),
    }, SetOptions(merge: true));
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserEmail),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // Typing indicator
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chatRooms')
                .doc(_chatId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 20);
              final data =
                  snap.data!.data() as Map<String, dynamic>? ?? {};
              final typing = data['typing'] ?? {};
              final otherTyping = typing[widget.otherUserId] == true;

              return otherTyping
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Typing…',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : const SizedBox(height: 20);
            },
          ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                _markSeen();
                final docs = snap.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final msg =
                        docs[i].data() as Map<String, dynamic>;
                    final isMe = msg['fromId'] == _myUid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.orange.shade300
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: msg['imageUrl'] != null
                                ? Image.network(
                                    msg['imageUrl'],
                                    width: 200,
                                  )
                                : Text(msg['text'] ?? ''),
                          ),

                          // Read receipt
                          if (isMe)
                            Text(
                              msg['seen'] == true ? 'Seen' : 'Delivered',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  color: Colors.orange,
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTyping,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.orange,
                  onPressed: _sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
