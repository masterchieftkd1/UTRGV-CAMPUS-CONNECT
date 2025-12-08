import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String chatId;
  bool chatCreated = false;

  @override
  void initState() {
    super.initState();
    _ensureChatRoomExists();
  }

  /// Create chat room or get existing ID
  Future<void> _ensureChatRoomExists() async {
    final String currentUid = _auth.currentUser!.uid;
    final String otherUid = widget.otherUserId;

    final existingChat = await _firestore
        .collection('chats')
        .where('members', arrayContains: currentUid)
        .get();

    for (var doc in existingChat.docs) {
      List members = doc['members'];
      if (members.contains(otherUid)) {
        chatId = doc.id;
        chatCreated = true;

        // Mark chat as seen on open
        _markChatSeen();
        setState(() {});
        return;
      }
    }

    // Create new chat if none exist
    final newChat = await _firestore.collection('chats').add({
      'members': [currentUid, otherUid],
      'lastMessage': "",
      'lastSender': "",
      'timestamp': FieldValue.serverTimestamp(),
      'seenBy': [currentUid], // current user seen by default
    });

    chatId = newChat.id;
    chatCreated = true;

    _markChatSeen();
    setState(() {});
  }

  /// Mark chat as seen
  Future<void> _markChatSeen() async {
    final currentUid = _auth.currentUser!.uid;

    await _firestore.collection('chats').doc(chatId).update({
      'seenBy': FieldValue.arrayUnion([currentUid]),
    });
  }

  /// Send message
  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    final String uid = _auth.currentUser!.uid;

    if (text.isEmpty) return;

    final timestamp = Timestamp.now();

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'text': text,
      'fromId': uid,
      'timestamp': timestamp,
    });

    // Update chat metadata
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastSender': uid,
      'timestamp': timestamp,
      'seenBy': [uid], // only sender seen
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final String otherEmail = widget.otherUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: Text(otherEmail),
        backgroundColor: Colors.orange,
      ),
      body: !chatCreated
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('timestamp')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      final currentUid = _auth.currentUser!.uid;

                      // FIX: Only mark seen when appropriate
                      if (docs.isNotEmpty) {
                        final last = docs.last.data() as Map<String, dynamic>? ?? {};
                        if (last["fromId"] != currentUid) {
                          _markChatSeen();
                        }
                      }

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("No messages yet."),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final msg = docs[index].data() as Map<String, dynamic>? ?? {};

                          final fromId = msg["fromId"] ?? "";
                          final text = msg["text"] ?? "";
                          final isMe = fromId == currentUid;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.orange.shade300
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Message Input Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.orange),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
