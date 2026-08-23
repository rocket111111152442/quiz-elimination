import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/werewolf_roles.dart';
import '../data/word_bank.dart';
import '../models/game_type.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../models/room.dart';
import '../models/undercover_room.dart';
import '../models/werewolf_room.dart';

class RoomNotFoundException implements Exception {}

class WerewolfCompositionException implements Exception {
  final String message;
  WerewolfCompositionException(this.message);
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

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
  // Loup-Garou
  // ---------------------------------------------------------------------

  static const _werewolfNightTemplate = [
    'cupidon',
    'salvateur',
    'loupGarou',
    'petiteFille',
    'voyante',
    'sorciere',
  ];

  List<String> _computeWerewolfNightOrder({
    required int roundIndex,
    required Map<String, bool> roleEnabled,
    required Map<String, String> roleByUid,
    required Set<String> aliveUids,
    required bool villagePowersLost,
  }) {
    final order = <String>[];
    for (final roleId in _werewolfNightTemplate) {
      if (roleId == 'cupidon') {
        if (roundIndex != 0) continue;
        if (!(roleEnabled['cupidon'] ?? false)) continue;
      } else if (roleId == 'loupGarou') {
        // Toujours en jeu tant qu'il reste un loup vivant.
      } else {
        if (!(roleEnabled[roleId] ?? false)) continue;
        if (villagePowersLost) continue;
      }
      final hasAliveHolder = roleByUid.entries.any(
        (e) => e.value == roleId && aliveUids.contains(e.key),
      );
      if (hasAliveHolder) order.add(roleId);
    }
    return order;
  }

  void _applyWerewolfLoversChain(Set<String> deaths, List<String> loversUids) {
    if (loversUids.length != 2) return;
    final a = loversUids[0];
    final b = loversUids[1];
    if (deaths.contains(a) && !deaths.contains(b)) deaths.add(b);
    if (deaths.contains(b) && !deaths.contains(a)) deaths.add(a);
  }

  /// null while the game continues, else 'village' | 'loups' | 'amoureux'.
  String? _checkWerewolfWinner({
    required Set<String> aliveUids,
    required Map<String, String> roleByUid,
    required List<String> loversUids,
  }) {
    if (aliveUids.length == 2 &&
        loversUids.length == 2 &&
        aliveUids.containsAll(loversUids)) {
      return 'amoureux';
    }
    final aliveWolves = aliveUids
        .where((uid) => roleByUid[uid] == 'loupGarou')
        .length;
    final aliveVillage = aliveUids.length - aliveWolves;
    if (aliveWolves == 0) return 'village';
    if (aliveWolves >= aliveVillage) return 'loups';
    return null;
  }

  /// Creates the room AND immediately joins the creator as a player — in
  /// Loup-Garou the "hôte" also plays, they just have a couple of extra
  /// narrator buttons (open the vote, close it) that other players don't.
  Future<String> createWerewolfRoom({
    required String hostUid,
    required String hostName,
  }) async {
    final code = await _findAvailableCode();
    await _roomDoc(code).set({
      'hostUid': hostUid,
      'gameType': GameType.werewolf.name,
      'status': WerewolfStatus.lobby.name,
      'loupGarouCount': 1,
      'roleEnabled': {
        for (final r in werewolfRoles.where((r) => r.isUnique)) r.id: false,
      },
      'roundIndex': 0,
      'nightOrder': <String>[],
      'nightStepIndex': 0,
      'werewolfVictimUid': null,
      'salvateurProtectedUid': null,
      'salvateurLastProtectedUid': null,
      'witchHealUsed': false,
      'witchKillUsed': false,
      'loversUids': <String>[],
      'villagePowersLost': false,
      'ancienImmunityUsed': false,
      'disenfranchisedUids': <String>[],
      'lastNightDeaths': <String>[],
      'lastVoteEliminated': null,
      'lastVoteTie': false,
      'lastVoteIdiotSurvived': false,
      'chainDeaths': <String>[],
      'pendingActorUid': null,
      'afterPending': null,
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _playersCol(code).doc(hostUid).set({
      'name': hostName,
      'alive': true,
      'eliminatedAtQuestion': null,
      'answers': <String, int>{},
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> updateWerewolfComposition({
    required String code,
    required int loupGarouCount,
    required Map<String, bool> roleEnabled,
  }) async {
    await _roomDoc(code)
        .update({'loupGarouCount': loupGarouCount, 'roleEnabled': roleEnabled});
  }

  /// Deals every joined player a role, computes night 0's order and starts
  /// the game. Throws [WerewolfCompositionException] if the chosen cards
  /// don't fit the number of joined players.
  Future<void> startWerewolfGame(String code) async {
    final roomSnap = await _roomDoc(code).get();
    final data = roomSnap.data()!;
    final loupGarouCount = (data['loupGarouCount'] as num).toInt();
    final roleEnabled = Map<String, dynamic>.from(
      data['roleEnabled'] as Map? ?? {},
    ).map((k, v) => MapEntry(k, v as bool));

    final playersSnap = await _playersCol(code).get();
    final uids = playersSnap.docs.map((d) => d.id).toList();

    final enabledUniqueRoles = roleEnabled.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final totalSpecial = loupGarouCount + enabledUniqueRoles.length;
    if (loupGarouCount < 1) {
      throw WerewolfCompositionException('Il faut au moins un Loup-Garou.');
    }
    if (totalSpecial > uids.length) {
      throw WerewolfCompositionException(
        'Trop de rôles sélectionnés ($totalSpecial) pour ${uids.length} '
        'joueur(s). Réduis-en certains.',
      );
    }

    final shuffled = [...uids]..shuffle();
    final wolfUids = shuffled.sublist(0, loupGarouCount);
    final specialUids = shuffled.sublist(loupGarouCount, totalSpecial);
    final roleByUid = <String, String>{};
    for (final uid in wolfUids) {
      roleByUid[uid] = 'loupGarou';
    }
    for (var i = 0; i < enabledUniqueRoles.length; i++) {
      roleByUid[specialUids[i]] = enabledUniqueRoles[i];
    }
    for (final uid in uids) {
      roleByUid.putIfAbsent(uid, () => 'villageois');
    }

    final nightOrder = _computeWerewolfNightOrder(
      roundIndex: 0,
      roleEnabled: roleEnabled,
      roleByUid: roleByUid,
      aliveUids: uids.toSet(),
      villagePowersLost: false,
    );

    final batch = _db.batch();
    for (final uid in uids) {
      batch.set(_roomDoc(code).collection('secrets').doc(uid), {
        'role': roleByUid[uid],
      });
    }
    batch.update(_roomDoc(code), {
      'status': WerewolfStatus.night.name,
      'roundIndex': 0,
      'nightOrder': nightOrder,
      'nightStepIndex': 0,
      'werewolfVictimUid': null,
      'salvateurProtectedUid': null,
      'salvateurLastProtectedUid': null,
      'witchHealUsed': false,
      'witchKillUsed': false,
      'loversUids': <String>[],
      'villagePowersLost': false,
      'ancienImmunityUsed': false,
      'disenfranchisedUids': <String>[],
      'lastNightDeaths': <String>[],
      'lastVoteEliminated': null,
      'lastVoteTie': false,
      'lastVoteIdiotSurvived': false,
      'chainDeaths': <String>[],
      'pendingActorUid': null,
      'afterPending': null,
      'winner': null,
    });
    await batch.commit();
  }

  /// Moves to the next role in the night order, or resolves dawn once the
  /// sequence is exhausted. Safe to call redundantly — it re-checks the
  /// room is still in [WerewolfStatus.night] before doing anything.
  Future<void> advanceWerewolfNightStep(String code) async {
    final roomRef = _roomDoc(code);
    var shouldResolveDawn = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      final data = snap.data()!;
      if (data['status'] != WerewolfStatus.night.name) return;
      final nightOrder = List<String>.from(data['nightOrder'] as List);
      final currentIndex = (data['nightStepIndex'] as num).toInt();
      final nextIndex = currentIndex + 1;
      if (nextIndex < nightOrder.length) {
        tx.update(roomRef, {'nightStepIndex': nextIndex});
      } else {
        shouldResolveDawn = true;
      }
    });
    if (shouldResolveDawn) {
      await _resolveWerewolfDawn(code);
    }
  }

  Future<void> submitWolfVote({
    required String code,
    required String uid,
    required int roundIndex,
    required String targetUid,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('wolfVotes')
        .doc(uid)
        .set({'votedFor': targetUid});

    final secretsSnap = await _roomDoc(code).collection('secrets').get();
    final playersSnap = await _playersCol(code).get();
    final aliveUids = {
      for (final d in playersSnap.docs)
        if (Player.fromMap(d.id, d.data()).alive) d.id,
    };
    final wolfUids = {
      for (final d in secretsSnap.docs)
        if (d.data()['role'] == 'loupGarou' && aliveUids.contains(d.id)) d.id,
    };
    final votesSnap = await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('wolfVotes')
        .get();
    final votesByUid = {
      for (final d in votesSnap.docs) d.id: d.data()['votedFor'] as String,
    };
    if (wolfUids.any((w) => !votesByUid.containsKey(w))) return;

    final tally = <String, int>{};
    for (final w in wolfUids) {
      final target = votesByUid[w]!;
      tally[target] = (tally[target] ?? 0) + 1;
    }
    final maxVotes = tally.values.fold(0, (m, v) => v > m ? v : m);
    final top =
        tally.entries
            .where((e) => e.value == maxVotes)
            .map((e) => e.key)
            .toList()
          ..shuffle();
    final victim = top.first;

    final roomRef = _roomDoc(code);
    final resolved = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(roomRef);
      final data = snap.data()!;
      if (data['status'] != WerewolfStatus.night.name) return false;
      if (data['werewolfVictimUid'] != null) return false;
      tx.update(roomRef, {'werewolfVictimUid': victim});
      return true;
    });
    if (resolved) {
      await advanceWerewolfNightStep(code);
    }
  }

  Future<void> submitSalvateurChoice({
    required String code,
    required String uid,
    required int roundIndex,
    required String targetUid,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('salvateurChoice')
        .doc(uid)
        .set({'targetUid': targetUid});
    await _roomDoc(code).update({'salvateurProtectedUid': targetUid});
    await advanceWerewolfNightStep(code);
  }

  /// Records the Voyante's pick but does NOT advance the night — she needs
  /// to actually see the revealed role first. Her screen calls
  /// [advanceWerewolfNightStep] itself once she's ready to continue.
  Future<void> submitVoyanteLook({
    required String code,
    required String uid,
    required int roundIndex,
    required String targetUid,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('voyanteLooks')
        .doc(uid)
        .set({'targetUid': targetUid});
  }

  Stream<String?> voyanteLookTargetStream(
    String code,
    int roundIndex,
    String uid,
  ) {
    return _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('voyanteLooks')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['targetUid'] as String?);
  }

  Future<void> submitWitchAction({
    required String code,
    required String uid,
    required int roundIndex,
    required bool heal,
    String? killTargetUid,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('witchActions')
        .doc(uid)
        .set({'heal': heal, 'killTargetUid': killTargetUid});
    final updates = <String, dynamic>{};
    if (heal) updates['witchHealUsed'] = true;
    if (killTargetUid != null) updates['witchKillUsed'] = true;
    if (updates.isNotEmpty) await _roomDoc(code).update(updates);
    await advanceWerewolfNightStep(code);
  }

  Future<void> submitCupidonChoice({
    required String code,
    required String uid,
    required List<String> loverUids,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('0')
        .collection('cupidonChoice')
        .doc(uid)
        .set({'loverUids': loverUids});
    await _roomDoc(code).update({'loversUids': loverUids});
    await advanceWerewolfNightStep(code);
  }

  Future<void> _resolveWerewolfDawn(String code) async {
    final roomRef = _roomDoc(code);
    final roomSnap = await roomRef.get();
    final data = roomSnap.data()!;
    final roundIndex = (data['roundIndex'] as num).toInt();
    final werewolfVictimUid = data['werewolfVictimUid'] as String?;
    final salvateurProtectedUid = data['salvateurProtectedUid'] as String?;
    final loversUids = List<String>.from(data['loversUids'] as List? ?? []);
    var ancienImmunityUsed = data['ancienImmunityUsed'] as bool? ?? false;

    final secretsSnap = await roomRef.collection('secrets').get();
    final roleByUid = {
      for (final d in secretsSnap.docs) d.id: d.data()['role'] as String,
    };

    final witchActionsSnap = await roomRef
        .collection('rounds')
        .doc('$roundIndex')
        .collection('witchActions')
        .get();
    var witchHealedThisRound = false;
    String? witchKillTarget;
    if (witchActionsSnap.docs.isNotEmpty) {
      final witchData = witchActionsSnap.docs.first.data();
      witchHealedThisRound = witchData['heal'] as bool? ?? false;
      witchKillTarget = witchData['killTargetUid'] as String?;
    }

    final playersSnap = await _playersCol(code).get();
    final aliveBefore = {
      for (final d in playersSnap.docs)
        if (Player.fromMap(d.id, d.data()).alive) d.id,
    };

    final deaths = <String>{};
    if (werewolfVictimUid != null &&
        werewolfVictimUid != salvateurProtectedUid &&
        !witchHealedThisRound) {
      deaths.add(werewolfVictimUid);
    }
    if (witchKillTarget != null) {
      deaths.add(witchKillTarget);
    }

    final ancienUid = roleByUid.entries
        .firstWhereOrNull((e) => e.value == 'ancien')
        ?.key;
    if (ancienUid != null &&
        deaths.contains(ancienUid) &&
        werewolfVictimUid == ancienUid &&
        !ancienImmunityUsed) {
      deaths.remove(ancienUid);
      ancienImmunityUsed = true;
    }

    _applyWerewolfLoversChain(deaths, loversUids);
    final trulyDead = deaths.where(aliveBefore.contains).toList();

    final batch = _db.batch();
    for (final uid in trulyDead) {
      batch.update(_playersCol(code).doc(uid), {
        'alive': false,
        'eliminatedAtQuestion': roundIndex,
      });
    }
    batch.update(roomRef, {
      'lastNightDeaths': trulyDead,
      'salvateurLastProtectedUid': salvateurProtectedUid,
      'salvateurProtectedUid': null,
      'ancienImmunityUsed': ancienImmunityUsed,
      'chainDeaths': <String>[],
    });
    await batch.commit();

    final remainingAlive = {...aliveBefore}..removeAll(trulyDead);
    final winner = _checkWerewolfWinner(
      aliveUids: remainingAlive,
      roleByUid: roleByUid,
      loversUids: loversUids,
    );
    if (winner != null) {
      await roomRef.update({
        'status': WerewolfStatus.finished.name,
        'winner': winner,
      });
      return;
    }

    final chasseurDead = trulyDead.firstWhereOrNull(
      (uid) => roleByUid[uid] == 'chasseur',
    );
    if (chasseurDead != null) {
      await roomRef.update({
        'status': WerewolfStatus.hunterRevenge.name,
        'pendingActorUid': chasseurDead,
        'afterPending': WerewolfStatus.dayReveal.name,
      });
    } else {
      await roomRef.update({'status': WerewolfStatus.dayReveal.name});
    }
  }

  Future<void> submitHunterRevenge({
    required String code,
    required String hunterUid,
    required String targetUid,
  }) async {
    final roomRef = _roomDoc(code);
    final roomSnap = await roomRef.get();
    final data = roomSnap.data()!;
    if (data['status'] != WerewolfStatus.hunterRevenge.name) return;
    if (data['pendingActorUid'] != hunterUid) return;
    final roundIndex = (data['roundIndex'] as num).toInt();
    final loversUids = List<String>.from(data['loversUids'] as List? ?? []);
    final afterPending = werewolfStatusFromString(
      data['afterPending'] as String,
    );
    final existingChainDeaths = List<String>.from(
      data['chainDeaths'] as List? ?? [],
    );

    final secretsSnap = await roomRef.collection('secrets').get();
    final roleByUid = {
      for (final d in secretsSnap.docs) d.id: d.data()['role'] as String,
    };
    final playersSnap = await _playersCol(code).get();
    final aliveBefore = {
      for (final d in playersSnap.docs)
        if (Player.fromMap(d.id, d.data()).alive) d.id,
    };

    final deaths = <String>{targetUid};
    _applyWerewolfLoversChain(deaths, loversUids);
    final trulyDead = deaths.where(aliveBefore.contains).toList();

    final batch = _db.batch();
    for (final uid in trulyDead) {
      batch.update(_playersCol(code).doc(uid), {
        'alive': false,
        'eliminatedAtQuestion': roundIndex,
      });
    }
    batch.update(roomRef, {
      'chainDeaths': [...existingChainDeaths, ...trulyDead],
    });
    await batch.commit();

    final remainingAlive = {...aliveBefore}..removeAll(trulyDead);
    final winner = _checkWerewolfWinner(
      aliveUids: remainingAlive,
      roleByUid: roleByUid,
      loversUids: loversUids,
    );
    if (winner != null) {
      await roomRef.update({
        'status': WerewolfStatus.finished.name,
        'winner': winner,
        'pendingActorUid': null,
      });
      return;
    }

    final anotherHunter = trulyDead.firstWhereOrNull(
      (uid) => uid != hunterUid && roleByUid[uid] == 'chasseur',
    );
    if (anotherHunter != null) {
      await roomRef.update({'pendingActorUid': anotherHunter});
    } else {
      await roomRef.update({
        'status': afterPending.name,
        'pendingActorUid': null,
        'afterPending': null,
      });
    }
  }

  /// Host-only (enforced client-side): opens the village vote after the
  /// dawn reveal has been shown.
  Future<void> openWerewolfDayVote(String code) async {
    await _roomDoc(code).update({'status': WerewolfStatus.dayVote.name});
  }

  Future<void> submitWerewolfDayVote({
    required String code,
    required String uid,
    required int roundIndex,
    required String votedFor,
  }) async {
    await _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('dayVotes')
        .doc(uid)
        .set({'votedFor': votedFor});
  }

  Stream<Map<String, String>> werewolfDayVotesStream(
    String code,
    int roundIndex,
  ) {
    return _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('dayVotes')
        .snapshots()
        .map(
          (snap) => {
            for (final d in snap.docs) d.id: d.data()['votedFor'] as String,
          },
        );
  }

  /// Host-only (enforced client-side): tallies the village's vote and
  /// resolves every consequence (Idiot du Village surviving, Ancien
  /// stripping village powers, Bouc Émissaire absorbing a tie, Chasseur's
  /// revenge, lovers' heartbreak, win conditions).
  Future<void> tallyWerewolfDayVote(String code) async {
    final roomRef = _roomDoc(code);
    final roomSnap = await roomRef.get();
    final data = roomSnap.data()!;
    final roundIndex = (data['roundIndex'] as num).toInt();
    final disenfranchised = List<String>.from(
      data['disenfranchisedUids'] as List? ?? [],
    );
    final villagePowersLost = data['villagePowersLost'] as bool? ?? false;
    final roleEnabled = Map<String, dynamic>.from(
      data['roleEnabled'] as Map? ?? {},
    ).map((k, v) => MapEntry(k, v as bool));

    final votesSnap = await roomRef
        .collection('rounds')
        .doc('$roundIndex')
        .collection('dayVotes')
        .get();
    final tally = <String, int>{};
    for (final d in votesSnap.docs) {
      if (disenfranchised.contains(d.id)) continue;
      final target = d.data()['votedFor'] as String;
      tally[target] = (tally[target] ?? 0) + 1;
    }

    final secretsSnap = await roomRef.collection('secrets').get();
    final roleByUid = {
      for (final d in secretsSnap.docs) d.id: d.data()['role'] as String,
    };
    final playersSnap = await _playersCol(code).get();
    final aliveBefore = {
      for (final d in playersSnap.docs)
        if (Player.fromMap(d.id, d.data()).alive) d.id,
    };

    String? eliminated;
    var tie = false;
    if (tally.isNotEmpty) {
      final maxVotes = tally.values.fold(0, (m, v) => v > m ? v : m);
      final top = tally.entries
          .where((e) => e.value == maxVotes)
          .map((e) => e.key)
          .toList();
      if (top.length == 1) {
        eliminated = top.first;
      } else {
        tie = true;
        if (!villagePowersLost && (roleEnabled['boucEmissaire'] ?? false)) {
          eliminated = roleByUid.entries
              .firstWhereOrNull(
                (e) =>
                    e.value == 'boucEmissaire' && aliveBefore.contains(e.key),
              )
              ?.key;
        }
      }
    }

    if (eliminated == null) {
      await roomRef.update({
        'status': WerewolfStatus.voteReveal.name,
        'lastVoteEliminated': null,
        'lastVoteTie': tie,
        'lastVoteIdiotSurvived': false,
        'chainDeaths': <String>[],
      });
      return;
    }

    if (roleByUid[eliminated] == 'idiotDuVillage' && !villagePowersLost) {
      await roomRef.update({
        'status': WerewolfStatus.voteReveal.name,
        'lastVoteEliminated': null,
        'lastVoteTie': tie,
        'lastVoteIdiotSurvived': true,
        'disenfranchisedUids': [...disenfranchised, eliminated],
        'chainDeaths': <String>[],
      });
      return;
    }

    final deaths = <String>{eliminated};
    final loversUids = List<String>.from(data['loversUids'] as List? ?? []);
    _applyWerewolfLoversChain(deaths, loversUids);
    final trulyDead = deaths.where(aliveBefore.contains).toList();

    final batch = _db.batch();
    for (final uid in trulyDead) {
      batch.update(_playersCol(code).doc(uid), {
        'alive': false,
        'eliminatedAtQuestion': roundIndex,
      });
    }
    final newVillagePowersLost =
        villagePowersLost || roleByUid[eliminated] == 'ancien';
    batch.update(roomRef, {
      'lastVoteEliminated': eliminated,
      'lastVoteTie': tie,
      'lastVoteIdiotSurvived': false,
      'villagePowersLost': newVillagePowersLost,
      'chainDeaths': <String>[],
    });
    await batch.commit();

    final remainingAlive = {...aliveBefore}..removeAll(trulyDead);
    final winner = _checkWerewolfWinner(
      aliveUids: remainingAlive,
      roleByUid: roleByUid,
      loversUids: loversUids,
    );
    if (winner != null) {
      await roomRef.update({
        'status': WerewolfStatus.finished.name,
        'winner': winner,
      });
      return;
    }

    final chasseurDead = trulyDead.firstWhereOrNull(
      (uid) => roleByUid[uid] == 'chasseur',
    );
    if (chasseurDead != null) {
      await roomRef.update({
        'status': WerewolfStatus.hunterRevenge.name,
        'pendingActorUid': chasseurDead,
        'afterPending': WerewolfStatus.voteReveal.name,
      });
    } else {
      await roomRef.update({'status': WerewolfStatus.voteReveal.name});
    }
  }

  Future<void> startNextWerewolfRound(String code) async {
    final roomRef = _roomDoc(code);
    final roomSnap = await roomRef.get();
    final data = roomSnap.data()!;
    final roundIndex = (data['roundIndex'] as num).toInt();
    final roleEnabled = Map<String, dynamic>.from(
      data['roleEnabled'] as Map? ?? {},
    ).map((k, v) => MapEntry(k, v as bool));
    final villagePowersLost = data['villagePowersLost'] as bool? ?? false;

    final secretsSnap = await roomRef.collection('secrets').get();
    final roleByUid = {
      for (final d in secretsSnap.docs) d.id: d.data()['role'] as String,
    };
    final playersSnap = await _playersCol(code).get();
    final aliveUids = {
      for (final d in playersSnap.docs)
        if (Player.fromMap(d.id, d.data()).alive) d.id,
    };

    final nextRound = roundIndex + 1;
    final nightOrder = _computeWerewolfNightOrder(
      roundIndex: nextRound,
      roleEnabled: roleEnabled,
      roleByUid: roleByUid,
      aliveUids: aliveUids,
      villagePowersLost: villagePowersLost,
    );

    await roomRef.update({
      'status': WerewolfStatus.night.name,
      'roundIndex': nextRound,
      'nightOrder': nightOrder,
      'nightStepIndex': 0,
      'werewolfVictimUid': null,
    });
  }

  Stream<WerewolfRoom?> werewolfRoomStream(String code) {
    return _roomDoc(code).snapshots().map(
      (snap) => snap.exists ? WerewolfRoom.fromMap(code, snap.data()!) : null,
    );
  }

  Stream<String?> roleStream(String code, String uid) {
    return _roomDoc(code)
        .collection('secrets')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['role'] as String?);
  }

  /// Werewolves recognise each other on the first night, same as around a
  /// real table — this reads every player whose role is 'loupGarou',
  /// which the security rules only allow for a requester who is
  /// themselves a werewolf.
  Stream<List<String>> wolfTeammatesStream(String code) {
    return _roomDoc(code)
        .collection('secrets')
        .where('role', isEqualTo: 'loupGarou')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  Stream<Map<String, String>> wolfVotesStream(String code, int roundIndex) {
    return _roomDoc(code)
        .collection('rounds')
        .doc('$roundIndex')
        .collection('wolfVotes')
        .snapshots()
        .map(
          (snap) => {
            for (final d in snap.docs) d.id: d.data()['votedFor'] as String,
          },
        );
  }
}
