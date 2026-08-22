import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/answer_button.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/results_view.dart';

/// Single reactive screen driving the whole game for a player: lobby,
/// question, reveal and final results, all derived from the room's
/// Firestore [Room.status].
class PlayerLobbyScreen extends StatefulWidget {
  final String code;

  const PlayerLobbyScreen({super.key, required this.code});

  @override
  State<PlayerLobbyScreen> createState() => _PlayerLobbyScreenState();
}

class _PlayerLobbyScreenState extends State<PlayerLobbyScreen> {
  final _roomService = RoomService();
  final _authService = AuthService();
  int? _selectedOption;
  int? _selectedForQuestionIndex;

  String get _uid => _authService.currentUid!;

  Future<void> _answer(int questionIndex, int optionIndex) async {
    setState(() {
      _selectedOption = optionIndex;
      _selectedForQuestionIndex = questionIndex;
    });
    await _roomService.submitAnswer(
      code: widget.code,
      uid: _uid,
      questionIndex: questionIndex,
      optionIndex: optionIndex,
    );
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
                final me = players.where((p) => p.uid == _uid).firstOrNull;

                switch (room.status) {
                  case RoomStatus.lobby:
                    return Center(
                      child: Text(
                        'En attente que l\'hôte démarre la partie...\n'
                        '${players.length} joueur(s) dans la salle',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  case RoomStatus.question:
                    return _QuestionView(
                      room: room,
                      me: me,
                      selectedOption:
                          _selectedForQuestionIndex == room.currentQuestionIndex
                          ? _selectedOption
                          : null,
                      onAnswer: (optionIndex) =>
                          _answer(room.currentQuestionIndex, optionIndex),
                    );
                  case RoomStatus.reveal:
                    return _RevealView(room: room, me: me);
                  case RoomStatus.finished:
                    return ResultsView(players: players, highlightUid: _uid);
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

class _QuestionView extends StatelessWidget {
  final Room room;
  final Player? me;
  final int? selectedOption;
  final ValueChanged<int> onAnswer;

  const _QuestionView({
    required this.room,
    required this.me,
    required this.selectedOption,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final question = room.currentQuestion!;
    final eliminated = me != null && !me!.alive;

    if (eliminated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '💀 Tu es éliminé.\nRegarde la suite de la partie !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: Colors.white70),
          ),
        ),
      );
    }

    final hasAnswered = selectedOption != null;
    final startedAt = room.questionStartedAt?.toDate();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (startedAt != null)
            CountdownTimer(
              startedAt: startedAt,
              durationSeconds: question.timeLimitSeconds,
            ),
          const SizedBox(height: 12),
          Text(
            question.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                for (var i = 0; i < question.options.length; i++)
                  AnswerButton(
                    text: question.options[i],
                    index: i,
                    state: selectedOption == i
                        ? AnswerButtonState.selected
                        : AnswerButtonState.neutral,
                    onTap: hasAnswered ? null : () => onAnswer(i),
                  ),
              ],
            ),
          ),
          if (hasAnswered)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Réponse envoyée, attends les autres...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _RevealView extends StatelessWidget {
  final Room room;
  final Player? me;

  const _RevealView({required this.room, required this.me});

  @override
  Widget build(BuildContext context) {
    final question = room.currentQuestion!;
    final justEliminated =
        me?.eliminatedAtQuestion == room.currentQuestionIndex;
    final stillAlive = me?.alive ?? false;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Bonne réponse', style: TextStyle(color: Colors.white70)),
          Text(
            question.options[question.correctIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 32),
          if (justEliminated)
            const Text(
              '💀 Tu es éliminé sur cette question.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: AppColors.danger),
            )
          else if (stillAlive)
            const Text(
              '✅ Bien joué, tu continues !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: AppColors.success),
            )
          else
            const Text(
              'Tu regardes la suite de la partie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
