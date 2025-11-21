import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ----------------------------------------------------------
  // SIGN IN
  // ----------------------------------------------------------
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Login failed.";
    }
  }

  // ----------------------------------------------------------
  // SIGN UP + CREATE FULL USER DOCUMENT
  // ----------------------------------------------------------
  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) throw "User creation failed.";

      // ⭐ Complete Firestore user document
      await _firestore.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "email": email,
        "createdAt": FieldValue.serverTimestamp(),

        // 🔥 REQUIRED for friend/message system:
        "friends": [],
        "incomingRequests": [],
        "outgoingRequests": [],

        // 🔥 Profile fields:
        "photoUrl": null,
        "name": "",
        "bio": "",
        "phone": "",
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Account creation failed.";
    }
  }

  // ----------------------------------------------------------
  // SIGN OUT
  // ----------------------------------------------------------
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ----------------------------------------------------------
  // AUTH STATE STREAM
  // ----------------------------------------------------------
  Stream<User?> get userChanges => _auth.authStateChanges();
}
