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
  final _controller = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  late String roomId;

  @override
  void initState() {
    super.initState();
    roomId = _getRoomId(uid, widget.otherUserId);
    _setTyping(false);
  }

  @override
  void dispose() {
    _setTyping(false);
    super.dispose();
  }

  String _getRoomId(String a, String b) {
    return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
  }

  Future<void> _setTyping(bool typing) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .set({
      'typing': {uid: typing}
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _setTyping(false);

    final roomRef =
        FirebaseFirestore.instance.collection('chatRooms').doc(roomId);

    await roomRef.set({
      'participants': [uid, widget.otherUserId],
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await roomRef.collection('messages').add({
      'senderId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': [uid],
    });
  }

  void _markSeen(List<QueryDocumentSnapshot> messages) {
    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      final List seenBy = data['seenBy'] ?? [];
      if (!seenBy.contains(uid)) {
        doc.reference.update({
          'seenBy': FieldValue.arrayUnion([uid]),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomRef =
        FirebaseFirestore.instance.collection('chatRooms').doc(roomId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.otherUserId)
              .snapshots(),
          builder: (_, snap) {
            final data =
                snap.data?.data() as Map<String, dynamic>? ?? {};
            final isOnline = data['isOnline'] ?? false;

            return Row(
              children: [
                Text(widget.otherUserEmail),
                const SizedBox(width: 8),
                Icon(
                  Icons.circle,
                  size: 10,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // 🔴 Typing indicator
          StreamBuilder<DocumentSnapshot>(
            stream: roomRef.snapshots(),
            builder: (_, snap) {
              final typing =
                  (snap.data?.data() as Map<String, dynamic>?)?['typing']
                          as Map<String, dynamic>? ??
                      {};
              final isTyping = typing[widget.otherUserId] == true;

              if (!isTyping) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.all(6),
                child: Text(
                  "Typing...",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: roomRef
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                _markSeen(messages);

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == uid;
                    final List seenBy = msg['seenBy'] ?? [];

                    String status = '';
                    if (isMe) {
                      if (seenBy.contains(widget.otherUserId)) {
                        status = 'Seen';
                      } else {
                        status = 'Delivered';
                      }
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['text'],
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                          if (status.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => _setTyping(v.isNotEmpty),
                    decoration: const InputDecoration(
                        hintText: 'Message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send,
                      color: Colors.orange),
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
