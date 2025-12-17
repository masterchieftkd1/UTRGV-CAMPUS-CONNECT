import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static void init() {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    // ✅ SET ONLINE IMMEDIATELY
    userRef.update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });

    // ✅ SET OFFLINE WHEN TAB CLOSES
    html.window.addEventListener('beforeunload', (event) async {
      await userRef.update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    });
  }
}
