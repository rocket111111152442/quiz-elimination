import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  String? get currentUid => _auth.currentUser?.uid;
}
