import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player.dart';
import '../models/question.dart';
import '../models/room.dart';

class RoomNotFoundException implements Exception {}

class RoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 5;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> _roomDoc(String code) =>
      _rooms.doc(code);

  CollectionReference<Map<String, dynamic>> _playersCol(String code) =>
      _roomDoc(code).collection('players');

  String _generateCode() {
    final random = Random();
    return List.generate(
      _codeLength,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  Future<String> createRoom({
    required String hostUid,
    required List<Question> questions,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateCode();
      final doc = _roomDoc(code);
      final existing = await doc.get();
      if (existing.exists) continue;
      await doc.set({
        'hostUid': hostUid,
        'status': RoomStatus.lobby.name,
        'questions': questions.map((q) => q.toMap()).toList(),
        'currentQuestionIndex': -1,
        'questionStartedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return code;
    }
    throw StateError(
      'Impossible de générer un code de salle unique, réessaie.',
    );
  }

  Future<void> joinRoom({
    required String code,
    required String uid,
    required String name,
  }) async {
    final roomSnap = await _roomDoc(code).get();
    if (!roomSnap.exists) throw RoomNotFoundException();
    await _playersCol(code).doc(uid).set({
      'name': name,
      'alive': true,
      'eliminatedAtQuestion': null,
      'answers': <String, int>{},
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Room?> roomStream(String code) {
    return _roomDoc(code)
        .snapshots()
        .map((snap) => snap.exists ? Room.fromMap(code, snap.data()!) : null);
  }

  Stream<List<Player>> playersStream(String code) {
    return _playersCol(code).snapshots().map(
      (snap) =>
          snap.docs.map((doc) => Player.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> submitAnswer({
    required String code,
    required String uid,
    required int questionIndex,
    required int optionIndex,
  }) async {
    await _playersCol(code)
        .doc(uid)
        .update({'answers.$questionIndex': optionIndex});
  }

  Future<void> startGame(String code) async {
    await _roomDoc(code).update({
      'status': RoomStatus.question.name,
      'currentQuestionIndex': 0,
      'questionStartedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Compares every alive player's answer for [questionIndex] against
  /// [correctIndex] and eliminates whoever answered wrong or didn't answer.
  Future<void> revealAndEliminate({
    required String code,
    required int questionIndex,
    required int correctIndex,
  }) async {
    final playersSnap = await _playersCol(code).get();
    final batch = _db.batch();
    for (final doc in playersSnap.docs) {
      final player = Player.fromMap(doc.id, doc.data());
      if (!player.alive) continue;
      final answer = player.answerFor(questionIndex);
      if (answer != correctIndex) {
        batch.update(doc.reference, {
          'alive': false,
          'eliminatedAtQuestion': questionIndex,
        });
      }
    }
    batch.update(_roomDoc(code), {'status': RoomStatus.reveal.name});
    await batch.commit();
  }

  Future<void> nextQuestion(String code, int newIndex) async {
    await _roomDoc(code).update({
      'status': RoomStatus.question.name,
      'currentQuestionIndex': newIndex,
      'questionStartedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> finishGame(String code) async {
    await _roomDoc(code).update({'status': RoomStatus.finished.name});
  }
}
