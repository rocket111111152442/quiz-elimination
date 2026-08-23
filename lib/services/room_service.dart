import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/word_bank.dart';
import '../models/game_type.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../models/room.dart';
import '../models/undercover_room.dart';

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

  Future<String> _findAvailableCode() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateCode();
      final existing = await _roomDoc(code).get();
      if (!existing.exists) return code;
    }
    throw StateError(
      'Impossible de générer un code de salle unique, réessaie.',
    );
  }

  Future<String> createRoom({
    required String hostUid,
    required List<Question> questions,
  }) async {
    final code = await _findAvailableCode();
    await _roomDoc(code).set({
      'hostUid': hostUid,
      'gameType': GameType.quiz.name,
      'status': RoomStatus.lobby.name,
      'questions': questions.map((q) => q.toMap()).toList(),
      'currentQuestionIndex': -1,
      'questionStartedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<GameType> joinRoom({
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
    return gameTypeFromString(roomSnap.data()?['gameType'] as String?);
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

  // ---------------------------------------------------------------------
  // Undercover
  // ---------------------------------------------------------------------

  Future<String> createUndercoverRoom({
    required String hostUid,
    required String category,
    required int undercoverCount,
  }) async {
    final code = await _findAvailableCode();
    await _roomDoc(code).set({
      'hostUid': hostUid,
      'gameType': GameType.undercover.name,
      'status': UndercoverStatus.lobby.name,
      'category': category,
      'undercoverCount': undercoverCount,
      'roundIndex': 0,
      'playerOrder': <String>[],
      'currentTurnIndex': 0,
      'eliminatedThisRound': null,
      'tieThisRound': false,
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Assigns roles/words to every joined player and starts round 0. Only
  /// the host calls this, once, from the lobby.
  Future<void> startUndercoverGame(String code) async {
    final roomSnap = await _roomDoc(code).get();
    final data = roomSnap.data()!;
    final category = data['category'] as String;
    final requestedUndercover = (data['undercoverCount'] as num).toInt();

    final playersSnap = await _playersCol(code).get();
    final uids = playersSnap.docs.map((d) => d.id).toList()..shuffle();

    final maxUndercover = uids.length - 2 < 1 ? 1 : uids.length - 2;
    final undercoverCount = requestedUndercover > maxUndercover
        ? maxUndercover
        : requestedUndercover;

    final candidates = category == 'Aléatoire'
        ? wordBank
        : wordBank.where((w) => w.category == category).toList();
    final pair = candidates[Random().nextInt(candidates.length)];

    final rolesShuffled = [...uids]..shuffle();
    final undercoverUids = rolesShuffled.take(undercoverCount).toSet();

    final batch = _db.batch();
    for (final uid in uids) {
      final isUndercover = undercoverUids.contains(uid);
      batch.set(_roomDoc(code).collection('secrets').doc(uid), {
        'role': isUndercover ? 'undercover' : 'civil',
        'word': isUndercover ? pair.undercoverWord : pair.civilWord,
      });
    }
    batch.set(_roomDoc(code).collection('meta').doc('words'), {
      'category': pair.category,
      'civilWord': pair.civilWord,
      'undercoverWord': pair.undercoverWord,
    });
    batch.update(_roomDoc(code), {
      'status': UndercoverStatus.clue.name,
      'playerOrder': uids,
      'roundIndex': 0,
      'currentTurnIndex': 0,
      'eliminatedThisRound': null,
      'tieThisRound': false,
      'winner': null,
    });
    await batch.commit();
  }

  Future<void> submitClue({
    required String code,
    required String uid,
    required int roundIndex,
    required String text,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('clues')
        .doc(uid)
        .set({'text': text, 'submittedAt': FieldValue.serverTimestamp()});
  }

  /// Host-only: passes the turn to the next player in [UndercoverRoom.playerOrder],
  /// or opens the vote once everyone has given their clue.
  Future<void> advanceClueTurn(String code) async {
    final roomSnap = await _roomDoc(code).get();
    final data = roomSnap.data()!;
    final playerOrder = List<String>.from(data['playerOrder'] as List);
    final currentTurnIndex = (data['currentTurnIndex'] as num).toInt();
    final nextIndex = currentTurnIndex + 1;
    if (nextIndex < playerOrder.length) {
      await _roomDoc(code).update({'currentTurnIndex': nextIndex});
    } else {
      await _roomDoc(
        code,
      ).update({'status': UndercoverStatus.voting.name, 'currentTurnIndex': 0});
    }
  }

  Future<void> submitVote({
    required String code,
    required String uid,
    required int roundIndex,
    required String votedFor,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('votes')
        .doc(uid)
        .set({'votedFor': votedFor});
  }

  /// Host-only: tallies the round's votes, eliminates whoever got the most
  /// (no elimination on a tie), and checks the win condition.
  Future<void> tallyVotesAndAdvance(String code) async {
    final roomRef = _roomDoc(code);
    final roomSnap = await roomRef.get();
    final data = roomSnap.data()!;
    final roundIndex = (data['roundIndex'] as num).toInt();
    final playerOrder = List<String>.from(data['playerOrder'] as List);

    final votesSnap = await roomRef
        .collection('rounds')
        .doc('$roundIndex')
        .collection('votes')
        .get();
    final tally = <String, int>{};
    for (final doc in votesSnap.docs) {
      final votedFor = doc.data()['votedFor'] as String;
      tally[votedFor] = (tally[votedFor] ?? 0) + 1;
    }
    final maxVotes = tally.values.fold(0, (m, v) => v > m ? v : m);
    final topUids = tally.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();
    final tie = maxVotes == 0 || topUids.length != 1;
    final eliminated = tie ? null : topUids.first;
    final remaining = eliminated == null
        ? playerOrder
        : playerOrder.where((p) => p != eliminated).toList();

    final secretsSnap = await roomRef.collection('secrets').get();
    final roleByUid = {
      for (final doc in secretsSnap.docs) doc.id: doc.data()['role'] as String,
    };
    final remainingUndercover = remaining
        .where((p) => roleByUid[p] == 'undercover')
        .length;
    final remainingCivil = remaining.length - remainingUndercover;
    String? winner;
    if (remainingUndercover == 0) {
      winner = 'civils';
    } else if (remainingUndercover >= remainingCivil) {
      winner = 'undercover';
    }

    final batch = _db.batch();
    batch.update(roomRef, {
      'status': UndercoverStatus.reveal.name,
      'eliminatedThisRound': eliminated,
      'tieThisRound': tie,
      'playerOrder': remaining,
      'winner': winner,
    });
    if (eliminated != null) {
      batch.update(_playersCol(code).doc(eliminated), {
        'alive': false,
        'eliminatedAtQuestion': roundIndex,
      });
    }
    await batch.commit();
  }

  Future<void> startNextUndercoverRound(String code) async {
    final roomSnap = await _roomDoc(code).get();
    final data = roomSnap.data()!;
    final playerOrder = List<String>.from(data['playerOrder'] as List)
      ..shuffle();
    final roundIndex = (data['roundIndex'] as num).toInt();
    await _roomDoc(code).update({
      'status': UndercoverStatus.clue.name,
      'roundIndex': roundIndex + 1,
      'playerOrder': playerOrder,
      'currentTurnIndex': 0,
      'eliminatedThisRound': null,
      'tieThisRound': false,
    });
  }

  Future<void> finishUndercoverGame(String code) async {
    await _roomDoc(code).update({'status': UndercoverStatus.finished.name});
  }

  Stream<UndercoverRoom?> undercoverRoomStream(String code) {
    return _roomDoc(code).snapshots().map(
      (snap) => snap.exists ? UndercoverRoom.fromMap(code, snap.data()!) : null,
    );
  }

  Stream<Map<String, String>> cluesStream(String code, int roundIndex) {
    return _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('clues')
        .snapshots()
        .map(
          (snap) => {
            for (final d in snap.docs) d.id: d.data()['text'] as String,
          },
        );
  }

  Stream<Map<String, String>> votesStream(String code, int roundIndex) {
    return _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('votes')
        .snapshots()
        .map(
          (snap) => {
            for (final d in snap.docs) d.id: d.data()['votedFor'] as String,
          },
        );
  }

  Stream<Map<String, dynamic>?> mySecretStream(String code, String uid) {
    return _roomDoc(code)
        .collection('secrets')
        .doc(uid)
        .snapshots()
        .map((s) => s.data());
  }

  Stream<Map<String, dynamic>?> gameWordsStream(String code) {
    return _roomDoc(code)
        .collection('meta')
        .doc('words')
        .snapshots()
        .map((s) => s.data());
  }

  Stream<Map<String, String>> allRolesStream(String code) {
    return _roomDoc(code)
        .collection('secrets')
        .snapshots()
        .map(
          (snap) => {
            for (final d in snap.docs) d.id: d.data()['role'] as String,
          },
        );
  }
}
