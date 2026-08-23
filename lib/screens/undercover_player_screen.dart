import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/undercover_room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/inactivity_badge.dart';
import '../widgets/undercover_results_view.dart';

/// Single reactive screen driving the whole Undercover game for a player:
/// lobby, clue rounds (typing on your turn), vote, reveal and final
/// results, all derived from [UndercoverRoom.status].
class UndercoverPlayerScreen extends StatefulWidget {
  final String code;

  const UndercoverPlayerScreen({super.key, required this.code});

  @override
  State<UndercoverPlayerScreen> createState() => _UndercoverPlayerScreenState();
}

class _UndercoverPlayerScreenState extends State<UndercoverPlayerScreen> {
  final _roomService = RoomService();
  final _authService = AuthService();
  final _clueController = TextEditingController();
  int? _votedForRound;
  String? _votedFor;
  final _guessController = TextEditingController();
  int? _guessSentForRound;

  String get _uid => _authService.currentUid!;

  @override
  void dispose() {
    _clueController.dispose();
    _guessController.dispose();
    super.dispose();
  }

  Future<void> _sendClue(int roundIndex) async {
    final text = _clueController.text.trim();
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return;
    await _roomService.submitClue(
      code: widget.code,
      uid: _uid,
      roundIndex: roundIndex,
      text: text,
    );
    _clueController.clear();
  }

  Future<void> _vote(int roundIndex, String votedFor) async {
    setState(() {
      _votedForRound = roundIndex;
      _votedFor = votedFor;
    });
    await _roomService.submitVote(
      code: widget.code,
      uid: _uid,
      roundIndex: roundIndex,
      votedFor: votedFor,
    );
  }

  Future<void> _sendGuess(int roundIndex) async {
    final text = _guessController.text.trim();
    if (text.isEmpty) return;
    setState(() => _guessSentForRound = roundIndex);
    await _roomService.submitMisterWhiteGuess(
      code: widget.code,
      uid: _uid,
      roundIndex: roundIndex,
      guess: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Salle ${widget.code}')),
      body: SafeArea(
        child: StreamBuilder<UndercoverRoom?>(
          stream: _roomService.undercoverRoomStream(widget.code),
          builder: (context, roomSnap) {
            final room = roomSnap.data;
            if (room == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<Player>>(
              stream: _roomService.playersStream(widget.code),
              builder: (context, playersSnap) {
                final players = playersSnap.data ?? [];
                final me = players.where((p) => p.uid == _uid).firstOrNull;
                final nameByUid = {for (final p in players) p.uid: p.name};

                switch (room.status) {
                  case UndercoverStatus.lobby:
                    return Center(
                      child: Text(
                        'En attente que l\'hôte démarre la partie...\n'
                        '${players.length} joueur(s) dans la salle',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  case UndercoverStatus.clue:
                    return _ClueView(
                      code: widget.code,
                      room: room,
                      me: me,
                      uid: _uid,
                      nameByUid: nameByUid,
                      clueController: _clueController,
                      roomService: _roomService,
                      onSend: () => _sendClue(room.roundIndex),
                    );
                  case UndercoverStatus.voting:
                    return _VotingView(
                      room: room,
                      me: me,
                      uid: _uid,
                      nameByUid: nameByUid,
                      myVote: _votedForRound == room.roundIndex
                          ? _votedFor
                          : null,
                      onVote: (votedFor) => _vote(room.roundIndex, votedFor),
                    );
                  case UndercoverStatus.misterWhiteGuess:
                    return _MisterWhiteGuessView(
                      room: room,
                      me: me,
                      guessController: _guessController,
                      guessSent: _guessSentForRound == room.roundIndex,
                      onSend: () => _sendGuess(room.roundIndex),
                    );
                  case UndercoverStatus.reveal:
                    return _RevealView(room: room, players: players);
                  case UndercoverStatus.finished:
                    return UndercoverResultsView(
                      code: widget.code,
                      players: players,
                      roomService: _roomService,
                      highlightUid: _uid,
                    );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ClueView extends StatelessWidget {
  final String code;
  final UndercoverRoom room;
  final Player? me;
  final String uid;
  final Map<String, String> nameByUid;
  final TextEditingController clueController;
  final RoomService roomService;
  final VoidCallback onSend;

  const _ClueView({
    required this.code,
    required this.room,
    required this.me,
    required this.uid,
    required this.nameByUid,
    required this.clueController,
    required this.roomService,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final eliminated = me != null && !me!.alive;
    final isMyTurn = room.currentTurnUid == uid && !eliminated;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (room.phaseStartedAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: InactivityBadge(since: room.phaseStartedAt!.toDate()),
            ),
          Text(
            'Manche ${room.roundIndex + 1}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          StreamBuilder<Map<String, dynamic>?>(
            stream: roomService.mySecretStream(code, uid),
            builder: (context, snap) {
              final role = snap.data?['role'] as String?;
              final word = snap.data?['word'] as String?;
              if (role == null) return const SizedBox.shrink();
              final isMisterWhite = role == 'mister_white';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMisterWhite ? Colors.amber : AppColors.primary,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isMisterWhite
                          ? '🎩 Tu es Mister White'
                          : 'Ton mot secret',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      isMisterWhite
                          ? 'Tu n\'as pas de mot ! Bluffe grâce aux indices des autres.'
                          : (word ?? ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMisterWhite ? 15 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (eliminated)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                '💀 Tu es éliminé.\nRegarde la suite de la partie !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            )
          else if (isMyTurn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'À toi de jouer !',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tour de ${room.currentTurnUid != null ? (nameByUid[room.currentTurnUid] ?? '...') : '...'}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<Map<String, String>>(
              stream: roomService.cluesStream(code, room.roundIndex),
              builder: (context, snap) {
                final clues = snap.data ?? {};
                return ListView(
                  children: [
                    for (final playerUid in room.playerOrder)
                      if (clues[playerUid] != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                          ),
                          title: Text(nameByUid[playerUid] ?? '...'),
                          trailing: Text(
                            clues[playerUid]!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    if (isMyTurn && clues[uid] == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: clueController,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'Un seul mot...',
                                ),
                                onSubmitted: (_) => onSend(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: onSend,
                              child: const Text('Envoyer'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VotingView extends StatelessWidget {
  final UndercoverRoom room;
  final Player? me;
  final String uid;
  final Map<String, String> nameByUid;
  final String? myVote;
  final ValueChanged<String> onVote;

  const _VotingView({
    required this.room,
    required this.me,
    required this.uid,
    required this.nameByUid,
    required this.myVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final eliminated = me != null && !me!.alive;
    if (eliminated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '💀 Tu es éliminé.\nRegarde qui va être démasqué !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: Colors.white70),
          ),
        ),
      );
    }
    if (myVote != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Vote envoyé : ${nameByUid[myVote] ?? '...'}\nEn attente des autres joueurs...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    }
    final choices = room.playerOrder.where((p) => p != uid).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (room.phaseStartedAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: InactivityBadge(since: room.phaseStartedAt!.toDate()),
            ),
          const Text(
            'Qui est l\'Undercover ?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                for (final playerUid in choices)
                  Card(
                    child: ListTile(
                      title: Text(nameByUid[playerUid] ?? '...'),
                      trailing: const Icon(Icons.how_to_vote_outlined),
                      onTap: () => onVote(playerUid),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MisterWhiteGuessView extends StatelessWidget {
  final UndercoverRoom room;
  final Player? me;
  final TextEditingController guessController;
  final bool guessSent;
  final VoidCallback onSend;

  const _MisterWhiteGuessView({
    required this.room,
    required this.me,
    required this.guessController,
    required this.guessSent,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isMisterWhite = me?.uid == room.eliminatedThisRound;
    if (!isMisterWhite) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '🎩 Mister White a été démasqué...\nIl a une dernière chance de deviner le mot des civils !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
      );
    }
    if (guessSent) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Devinette envoyée !\nOn regarde si t\'as gagné...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (room.phaseStartedAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: InactivityBadge(since: room.phaseStartedAt!.toDate()),
            ),
          const Text(
            '🎩 Tu es démasqué, mais il te reste une chance !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Devine le mot des civils pour gagner la partie.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: guessController,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: 'Ta réponse...'),
            onSubmitted: (_) => onSend(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSend,
              child: const Text('Valider ma devinette'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealView extends StatelessWidget {
  final UndercoverRoom room;
  final List<Player> players;

  const _RevealView({required this.room, required this.players});

  @override
  Widget build(BuildContext context) {
    final eliminatedName = room.eliminatedThisRound == null
        ? null
        : players
              .where((p) => p.uid == room.eliminatedThisRound)
              .map((p) => p.name)
              .firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (room.tieThisRound)
            const Text(
              'Égalité ! Personne n\'est éliminé.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            )
          else if (eliminatedName != null)
            Text(
              '$eliminatedName est éliminé(e) !',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          const SizedBox(height: 24),
          if (room.winner == 'civils')
            const Text(
              '🎉 Les civils gagnent !',
              style: TextStyle(fontSize: 20, color: AppColors.success),
            )
          else if (room.winner == 'imposteurs')
            const Text(
              '🕵️ Les imposteurs gagnent !',
              style: TextStyle(fontSize: 20, color: AppColors.danger),
            )
          else if (room.winner == 'mister_white')
            const Text(
              '🎩 Mister White a deviné le mot et gagne la partie !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.amber),
            )
          else
            const Text(
              'La partie continue...',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
