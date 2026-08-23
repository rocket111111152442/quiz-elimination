import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/word_bank.dart';
import '../models/game_type.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../models/racing_room.dart';
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
    required bool includeMisterWhite,
  }) async {
    final code = await _findAvailableCode();
    await _roomDoc(code).set({
      'hostUid': hostUid,
      'gameType': GameType.undercover.name,
      'status': UndercoverStatus.lobby.name,
      'category': category,
      'undercoverCount': undercoverCount,
      'includeMisterWhite': includeMisterWhite,
      'roundIndex': 0,
      'playerOrder': <String>[],
      'currentTurnIndex': 0,
      'eliminatedThisRound': null,
      'tieThisRound': false,
      'winner': null,
      'pendingWinner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Assigns roles/words to every joined player and starts round 0. Only
  /// the host calls this, once, from the lobby. Mister White is dealt like
  /// an Undercover but receives no word at all — they have to bluff blind.
  Future<void> startUndercoverGame(String code) async {
    final roomSnap = await _roomDoc(code).get();
    final data = roomSnap.data()!;
    final category = data['category'] as String;
    final requestedUndercover = (data['undercoverCount'] as num).toInt();
    final wantMisterWhite = data['includeMisterWhite'] as bool? ?? false;

    final playersSnap = await _playersCol(code).get();
    final uids = playersSnap.docs.map((d) => d.id).toList()..shuffle();

    final maxImpostors = uids.length - 2 < 1 ? 1 : uids.length - 2;
    var undercoverCount = requestedUndercover;
    var misterWhiteCount = wantMisterWhite ? 1 : 0;
    while (undercoverCount + misterWhiteCount > maxImpostors) {
      if (undercoverCount > 1) {
        undercoverCount--;
      } else if (misterWhiteCount > 0) {
        misterWhiteCount = 0;
      } else {
        break;
      }
    }

    final candidates = category == 'Aléatoire'
        ? wordBank
        : wordBank.where((w) => w.category == category).toList();
    final pair = candidates[Random().nextInt(candidates.length)];

    final rolesShuffled = [...uids]..shuffle();
    final undercoverUids = rolesShuffled.sublist(0, undercoverCount).toSet();
    final misterWhiteUids = rolesShuffled
        .sublist(undercoverCount, undercoverCount + misterWhiteCount)
        .toSet();

    final batch = _db.batch();
    for (final uid in uids) {
      final role = undercoverUids.contains(uid)
          ? 'undercover'
          : misterWhiteUids.contains(uid)
          ? 'mister_white'
          : 'civil';
      final word = role == 'undercover'
          ? pair.undercoverWord
          : role == 'civil'
          ? pair.civilWord
          : '';
      batch.set(_roomDoc(code).collection('secrets').doc(uid), {
        'role': role,
        'word': word,
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
      'pendingWinner': null,
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
  /// (no elimination on a tie), and checks the win condition. If the
  /// eliminated player is Mister White, the game pauses on
  /// [UndercoverStatus.misterWhiteGuess] instead of revealing the winner
  /// straight away — they get one shot at guessing the civil word first.
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
    final remainingImpostors = remaining
        .where((p) => roleByUid[p] != 'civil')
        .length;
    final remainingCivil = remaining.length - remainingImpostors;
    String? computedWinner;
    if (remainingImpostors == 0) {
      computedWinner = 'civils';
    } else if (remainingImpostors >= remainingCivil) {
      computedWinner = 'imposteurs';
    }

    final eliminatedRole = eliminated == null ? null : roleByUid[eliminated];
    final misterWhiteCaught = eliminatedRole == 'mister_white';

    final batch = _db.batch();
    batch.update(roomRef, {
      'status': misterWhiteCaught
          ? UndercoverStatus.misterWhiteGuess.name
          : UndercoverStatus.reveal.name,
      'eliminatedThisRound': eliminated,
      'tieThisRound': tie,
      'playerOrder': remaining,
      'winner': misterWhiteCaught ? null : computedWinner,
      'pendingWinner': misterWhiteCaught ? computedWinner : null,
    });
    if (eliminated != null) {
      batch.update(_playersCol(code).doc(eliminated), {
        'alive': false,
        'eliminatedAtQuestion': roundIndex,
      });
    }
    await batch.commit();
  }

  Future<void> submitMisterWhiteGuess({
    required String code,
    required String uid,
    required int roundIndex,
    required String guess,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('guesses')
        .doc(uid)
        .set({'guess': guess});
  }

  Stream<String?> misterWhiteGuessStream(
    String code,
    int roundIndex,
    String uid,
  ) {
    return _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('guesses')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['guess'] as String?);
  }

  /// Host-only: compares Mister White's guess against the civil word. A
  /// correct guess steals the win outright; otherwise the win check from
  /// [tallyVotesAndAdvance] (stored as `pendingWinner`) applies.
  Future<void> resolveMisterWhiteGuess(String code) async {
    final roomRef = _roomDoc(code);
    final roomSnap = await roomRef.get();
    final data = roomSnap.data()!;
    final roundIndex = (data['roundIndex'] as num).toInt();
    final eliminated = data['eliminatedThisRound'] as String?;
    final pendingWinner = data['pendingWinner'] as String?;
    if (eliminated == null) return;

    final guessSnap = await roomRef
        .collection('rounds')
        .doc('$roundIndex')
        .collection('guesses')
        .doc(eliminated)
        .get();
    final guess = (guessSnap.data()?['guess'] as String? ?? '')
        .trim()
        .toLowerCase();

    final wordsSnap = await roomRef.collection('meta').doc('words').get();
    final civilWord = (wordsSnap.data()?['civilWord'] as String? ?? '')
        .trim()
        .toLowerCase();

    final correct = guess.isNotEmpty && guess == civilWord;
    await roomRef.update({
      'status': UndercoverStatus.reveal.name,
      'winner': correct ? 'mister_white' : pendingWinner,
      'pendingWinner': null,
    });
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

  // ---------------------------------------------------------------------
  // Course de motos
  // ---------------------------------------------------------------------

  Future<String> createRacingRoom({required String hostUid}) async {
    final code = await _findAvailableCode();
    await _roomDoc(code).set({
      'hostUid': hostUid,
      'gameType': GameType.racing.name,
      'status': RacingStatus.lobby.name,
      'laps': 3,
      'countdownStartedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> setBike({
    required String code,
    required String uid,
    required String bikeId,
  }) async {
    await _playersCol(code).doc(uid).update({'bike': bikeId});
  }

  /// Host-only: kicks off the pre-race countdown. Every client derives the
  /// same race-start instant from this server timestamp, so no further
  /// writes are needed once the race is actually rolling.
  Future<void> startRace(String code) async {
    await _roomDoc(code).update({
      'status': RacingStatus.countdown.name,
      'countdownStartedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePosition({
    required String code,
    required String uid,
    required double x,
    required double y,
    required double heading,
  }) async {
    await _roomDoc(code).collection('positions').doc(uid).set({
      'x': x,
      'y': y,
      'heading': heading,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLapProgress({
    required String code,
    required String uid,
    required int lapsCompleted,
    bool finished = false,
    int? finishTimeMs,
  }) async {
    await _playersCol(code).doc(uid).update({
      'lapsCompleted': lapsCompleted,
      if (finished) 'finished': true,
      'finishTimeMs': ?finishTimeMs,
    });
  }

  Future<void> finishRacingGame(String code) async {
    await _roomDoc(code).update({'status': RacingStatus.finished.name});
  }

  Stream<RacingRoom?> racingRoomStream(String code) {
    return _roomDoc(code).snapshots().map(
      (snap) => snap.exists ? RacingRoom.fromMap(code, snap.data()!) : null,
    );
  }

  Stream<Map<String, CarPosition>> positionsStream(String code) {
    return _roomDoc(code)
        .collection('positions')
        .snapshots()
        .map(
          (snap) => {
            for (final d in snap.docs)
              d.id: CarPosition(
                x: (d.data()['x'] as num).toDouble(),
                y: (d.data()['y'] as num).toDouble(),
                heading: (d.data()['heading'] as num?)?.toDouble() ?? 0,
              ),
          },
        );
  }
}
