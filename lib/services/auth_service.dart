import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Lazy on purpose: a plain field initializer would call
  // FirebaseAuth.instance as soon as AuthService() is constructed, which
  // throws if Firebase hasn't been initialized yet (e.g. widget tests).
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  String? get currentUid => _auth.currentUser?.uid;
}
