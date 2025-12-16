import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setOnline(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setOffline(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
