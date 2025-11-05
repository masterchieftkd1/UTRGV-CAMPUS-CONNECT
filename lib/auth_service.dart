import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const allowedDomain = '@utrgv.edu';

  bool _isEmailAllowed(String email) =>
      email.toLowerCase().endsWith(allowedDomain);

  Future<UserCredential> signUp(String email, String password) async {
    if (!_isEmailAllowed(email)) {
      throw Exception('Only $allowedDomain emails are allowed.');
    }

    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) async {
    if (!_isEmailAllowed(email)) {
      throw Exception('Only $allowedDomain emails are allowed.');
    }

    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
