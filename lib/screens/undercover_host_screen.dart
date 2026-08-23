import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/undercover_room.dart';
import '../services/room_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/player_list_tile.dart';
import '../widgets/undercover_results_view.dart';

/// Single reactive screen driving the whole Undercover game for the host
/// (the "meneur de jeu"): lobby, clue rounds, vote, reveal and final
/// results, all derived from [UndercoverRoom.status]. The host is never a
/// player — exactly like the quiz's HostLobbyScreen.
class UndercoverHostScreen extends StatefulWidget {
  final String code;

  const UndercoverHostScreen({super.key, required this.code});

  @override
  State<UndercoverHostScreen> createState() => _UndercoverHostScreenState();
}

class _UndercoverHostScreenState extends State<UndercoverHostScreen> {
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
                final nameByUid = {for (final p in players) p.uid: p.name};
                switch (room.status) {
                  case UndercoverStatus.lobby:
                    return _LobbyView(
                      code: widget.code,
                      players: players,
                      loading: _actionInFlight,
                      onStart: players.length < 3
                          ? null
                          : () => _guardedAction(() async {
                              await SoundService.instance.play(GameSound.start);
                              await _roomService.startUndercoverGame(
                                widget.code,
                              );
                            }),
                    );
                  case UndercoverStatus.clue:
                    return _ClueHostView(
                      code: widget.code,
                      room: room,
                      nameByUid: nameByUid,
                      loading: _actionInFlight,
                      roomService: _roomService,
                      onAdvance: () => _guardedAction(
                        () => _roomService.advanceClueTurn(widget.code),
                      ),
                    );
                  case UndercoverStatus.voting:
                    return _VotingHostView(
                      code: widget.code,
                      room: room,
                      loading: _actionInFlight,
                      roomService: _roomService,
                      onTally: () => _guardedAction(
                        () => _roomService.tallyVotesAndAdvance(widget.code),
                      ),
                    );
                  case UndercoverStatus.reveal:
                    return _RevealHostView(
                      room: room,
                      players: players,
                      loading: _actionInFlight,
                      onContinue: room.winner != null
                          ? () => _guardedAction(
                              () => _roomService.finishUndercoverGame(
                                widget.code,
                              ),
                            )
                          : () => _guardedAction(
                              () => _roomService.startNextUndercoverRound(
                                widget.code,
                              ),
                            ),
                    );
                  case UndercoverStatus.finished:
                    return UndercoverResultsView(
                      code: widget.code,
                      players: players,
                      roomService: _roomService,
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
        if (players.length < 3)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Il faut au moins 3 joueurs pour démarrer.',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
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

class _ClueHostView extends StatelessWidget {
  final String code;
  final UndercoverRoom room;
  final Map<String, String> nameByUid;
  final bool loading;
  final RoomService roomService;
  final VoidCallback onAdvance;

  const _ClueHostView({
    required this.code,
    required this.room,
    required this.nameByUid,
    required this.loading,
    required this.roomService,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = room.currentTurnUid;
    final currentName = currentUid != null
        ? (nameByUid[currentUid] ?? '...')
        : null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Manche ${room.roundIndex + 1}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (currentName != null)
            Text(
              'C\'est au tour de $currentName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<Map<String, String>>(
              stream: roomService.cluesStream(code, room.roundIndex),
              builder: (context, snap) {
                final clues = snap.data ?? {};
                return ListView(
                  children: [
                    for (final uid in room.playerOrder)
                      if (clues[uid] != null)
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(nameByUid[uid] ?? '...'),
                          trailing: Text(
                            clues[uid]!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onAdvance,
              child: const Text('Joueur suivant'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VotingHostView extends StatelessWidget {
  final String code;
  final UndercoverRoom room;
  final bool loading;
  final RoomService roomService;
  final VoidCallback onTally;

  const _VotingHostView({
    required this.code,
    required this.room,
    required this.loading,
    required this.roomService,
    required this.onTally,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Qui est l\'Undercover ?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chaque joueur vote sur sa tablette...',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          StreamBuilder<Map<String, String>>(
            stream: roomService.votesStream(code, room.roundIndex),
            builder: (context, snap) {
              final votes = snap.data ?? {};
              return Text(
                '${votes.length} / ${room.playerOrder.length} ont voté',
                style: const TextStyle(fontSize: 18),
              );
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onTally,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Voir le résultat du vote'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealHostView extends StatelessWidget {
  final UndercoverRoom room;
  final List<Player> players;
  final bool loading;
  final VoidCallback onContinue;

  const _RevealHostView({
    required this.room,
    required this.players,
    required this.loading,
    required this.onContinue,
  });

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
          else if (room.winner == 'undercover')
            const Text(
              '🕵️ Les Undercover gagnent !',
              style: TextStyle(fontSize: 20, color: AppColors.danger),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onContinue,
              child: Text(
                room.winner != null
                    ? 'Voir les résultats finaux'
                    : 'Manche suivante',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
