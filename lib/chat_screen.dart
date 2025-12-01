import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final TextEditingController _messageController = TextEditingController();

  Timer? _typingTimer;

  String get _currentUid => _auth.currentUser!.uid;

  /// Stable chat ID
  String get _chatId {
    final ids = [_currentUid, widget.otherUserId]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  @override
  void initState() {
    super.initState();
    _ensureChatRoomExists();
    _markChatSeen();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _setTyping(false);
    _messageController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // FIXED — Ensures chat room exists AND has valid structure
  // -------------------------------------------------------------
  Future<void> _ensureChatRoomExists() async {
    final fs = FirebaseFirestore.instance;
    final roomRef = fs.collection("chatRooms").doc(_chatId);

    final snap = await roomRef.get();

    if (!snap.exists) {
      await roomRef.set({
        "participants": [_currentUid, widget.otherUserId],
        "lastMessage": "",
        "lastMessageFrom": "",
        "lastMessageTime": FieldValue.serverTimestamp(),
        "seenBy": [],
        "typing": {
          _currentUid: false,
          widget.otherUserId: false,
        },
      });
    } else {
      // Fix broken rooms automatically (self-healing)
      final data = snap.data() ?? {};

      if (!data.containsKey("participants")) {
        await roomRef.set({
          "participants": [_currentUid, widget.otherUserId],
        }, SetOptions(merge: true));
      }

      if (!data.containsKey("typing")) {
        await roomRef.set({
          "typing": {
            _currentUid: false,
            widget.otherUserId: false,
          }
        }, SetOptions(merge: true));
      }
    }
  }

  // -------------------------------------------------------------
  // TYPING INDICATOR
  // -------------------------------------------------------------
  Future<void> _setTyping(bool value) async {
    final roomRef =
        FirebaseFirestore.instance.collection("chatRooms").doc(_chatId);

    await roomRef.set({
      "typing": {
        _currentUid: value,
      }
    }, SetOptions(merge: true));
  }

  void _onTextChanged(String value) {
    final empty = value.trim().isEmpty;

    _typingTimer?.cancel();
    _setTyping(!empty);

    if (!empty) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _setTyping(false);
      });
    }
  }

  // -------------------------------------------------------------
  // SEND MESSAGE
  // -------------------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _typingTimer?.cancel();
    await _setTyping(false);

    final fs = FirebaseFirestore.instance;
    final roomRef = fs.collection("chatRooms").doc(_chatId);

    final msgRef = await roomRef.collection("messages").add({
      "fromId": _currentUid,
      "toId": widget.otherUserId,
      "text": text,
      "timestamp": FieldValue.serverTimestamp(),
    });

    await roomRef.set({
      "lastMessage": text,
      "lastMessageId": msgRef.id,
      "lastMessageFrom": _currentUid,
      "lastMessageTime": FieldValue.serverTimestamp(),
      "seenBy": [_currentUid],
    }, SetOptions(merge: true));
  }

  // -------------------------------------------------------------
  // MARK AS SEEN
  // -------------------------------------------------------------
  Future<void> _markChatSeen() async {
    final roomRef =
        FirebaseFirestore.instance.collection("chatRooms").doc(_chatId);

    await roomRef.set({
      "seenBy": FieldValue.arrayUnion([_currentUid]),
    }, SetOptions(merge: true));
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserEmail),
        backgroundColor: Colors.orange,
      ),

      body: Column(
        children: [

          // Typing / Seen Indicator
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("chatRooms")
                .doc(_chatId)
                .snapshots(),
            builder: (context, roomSnap) {
              String info = "";

              if (roomSnap.hasData && roomSnap.data!.exists) {
                final data =
                    roomSnap.data!.data() as Map<String, dynamic>? ?? {};

                // typing
                final typing = (data["typing"] ?? {}) as Map<String, dynamic>;
                final otherTyping = typing[widget.otherUserId] == true;

                if (otherTyping) {
                  info = "Typing...";
                } else {
                  final lastFrom = data["lastMessageFrom"] ?? "";
                  final seenBy =
                      ((data["seenBy"] as List?) ?? []).cast<String>();

                  if (lastFrom == currentUid) {
                    info = seenBy.contains(widget.otherUserId)
                        ? "Seen"
                        : "Delivered";
                  }
                }
              }

              return info.isEmpty
                  ? const SizedBox(height: 22)
                  : Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          info,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
            },
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("chatRooms")
                  .doc(_chatId)
                  .collection("messages")
                  .orderBy("timestamp")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                _markChatSeen();

                if (docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg =
                        docs[index].data() as Map<String, dynamic>? ?? {};

                    final fromId = msg["fromId"] ?? "";
                    final text = msg["text"] ?? "";
                    final isMe = fromId == currentUid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                        child: Text(text,
                            style: const TextStyle(fontSize: 15)),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: _onTextChanged,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.orange,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
