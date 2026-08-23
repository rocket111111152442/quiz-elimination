import 'dart:async';

import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/player_list_tile.dart';
import '../widgets/results_view.dart';

/// Single reactive screen driving the whole game for the host: lobby,
/// question, reveal and final results, all derived from the room's
/// Firestore [Room.status] so the host never needs to navigate manually.
class HostLobbyScreen extends StatefulWidget {
  final String code;

  const HostLobbyScreen({super.key, required this.code});

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  final _roomService = RoomService();
  bool _actionInFlight = false;

  Future<void> _guardedAction(Future<void> Function() action) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Salle ${widget.code}')),
      body: SafeArea(
        child: StreamBuilder<Room?>(
          stream: _roomService.roomStream(widget.code),
          builder: (context, roomSnap) {
            final room = roomSnap.data;
            if (room == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<Player>>(
              stream: _roomService.playersStream(widget.code),
              builder: (context, playersSnap) {
                final players = playersSnap.data ?? [];
                switch (room.status) {
                  case RoomStatus.lobby:
                    return _LobbyView(
                      code: widget.code,
                      players: players,
                      loading: _actionInFlight,
                      onStart: players.isEmpty
                          ? null
                          : () => _guardedAction(() async {
                              await SoundService.instance.play(GameSound.start);
                              await _roomService.startGame(widget.code);
                            }),
                    );
                  case RoomStatus.question:
                    return _QuestionView(
                      room: room,
                      players: players,
                      loading: _actionInFlight,
                      onReveal: () => _guardedAction(
                        () => _roomService.revealAndEliminate(
                          code: widget.code,
                          questionIndex: room.currentQuestionIndex,
                          correctIndex: room.currentQuestion!.correctIndex,
                        ),
                      ),
                    );
                  case RoomStatus.reveal:
                    final aliveCount = players.where((p) => p.alive).length;
                    final isLast = room.isLastQuestion;
                    return _RevealView(
                      room: room,
                      players: players,
                      loading: _actionInFlight,
                      onNext: (isLast || aliveCount <= 1)
                          ? () => _guardedAction(
                              () => _roomService.finishGame(widget.code),
                            )
                          : () => _guardedAction(
                              () => _roomService.nextQuestion(
                                widget.code,
                                room.currentQuestionIndex + 1,
                              ),
                            ),
                      nextLabel: (isLast || aliveCount <= 1)
                          ? 'Voir les résultats'
                          : 'Question suivante',
                    );
                  case RoomStatus.finished:
                    return ResultsView(players: players);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  final String code;
  final List<Player> players;
  final bool loading;
  final VoidCallback? onStart;

  const _LobbyView({
    required this.code,
    required this.players,
    required this.loading,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Code de la partie',
          style: TextStyle(color: Colors.white70),
        ),
        Text(
          code,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 16),
        Text('${players.length} joueur(s) connecté(s)'),
        Expanded(
          child: ListView(
            children: [for (final p in players) PlayerListTile(player: p)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onStart,
              child: const Text('Démarrer la partie'),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  final Room room;
  final List<Player> players;
  final bool loading;
  final VoidCallback onReveal;

  const _QuestionView({
    required this.room,
    required this.players,
    required this.loading,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final question = room.currentQuestion!;
    final alive = players.where((p) => p.alive).toList();
    final answered = alive
        .where((p) => p.answerFor(room.currentQuestionIndex) != null)
        .length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Question ${room.currentQuestionIndex + 1} / ${room.questions.length}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            question.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text(
            '$answered / ${alive.length} ont répondu',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '${alive.length} en jeu',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onReveal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Révéler la réponse'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealView extends StatefulWidget {
  final Room room;
  final List<Player> players;
  final bool loading;
  final VoidCallback onNext;
  final String nextLabel;

  const _RevealView({
    required this.room,
    required this.players,
    required this.loading,
    required this.onNext,
    required this.nextLabel,
  });

  @override
  State<_RevealView> createState() => _RevealViewState();
}

/// Auto-advances after a short pause so the host doesn't have to tap
/// through every single question manually — a "Continuer maintenant"
/// button is still there for whoever wants to skip the wait.
class _RevealViewState extends State<_RevealView> {
  static const _autoAdvanceSeconds = 3;
  Timer? _advanceTimer;
  Timer? _tickTimer;
  int _remainingSeconds = _autoAdvanceSeconds;

  @override
  void initState() {
    super.initState();
    _advanceTimer = Timer(
      const Duration(seconds: _autoAdvanceSeconds),
      widget.onNext,
    );
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(
        () => _remainingSeconds = (_remainingSeconds - 1).clamp(
          0,
          _autoAdvanceSeconds,
        ),
      );
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final players = widget.players;
    final question = room.currentQuestion!;
    final eliminatedNow = players
        .where((p) => p.eliminatedAtQuestion == room.currentQuestionIndex)
        .toList();
    final alive = players.where((p) => p.alive).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('Bonne réponse', style: TextStyle(color: Colors.white70)),
          Text(
            question.options[question.correctIndex],
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${alive.length} joueur(s) encore en jeu',
            style: const TextStyle(fontSize: 18),
          ),
          if (eliminatedNow.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Éliminé(s) :', style: TextStyle(color: Colors.white70)),
            Wrap(
              spacing: 8,
              children: [
                for (final p in eliminatedNow)
                  Chip(label: Text(p.name), backgroundColor: AppColors.danger),
              ],
            ),
          ],
          const Spacer(),
          Text(
            'Passage automatique dans $_remainingSeconds s...',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.loading ? null : widget.onNext,
              child: Text('${widget.nextLabel} maintenant'),
            ),
          ),
        ],
      ),
    );
  }
}
