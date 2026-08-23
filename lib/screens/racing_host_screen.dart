import 'package:flutter/material.dart';

import '../data/bike_specs.dart';
import '../models/player.dart';
import '../models/racing_room.dart';
import '../services/room_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/racing_results_view.dart';

/// Host screen for the racing mini-game: the host never drives, just sets
/// off the race and watches a live leaderboard, exactly like the quiz and
/// Undercover hosts stay off to the side of their games.
class RacingHostScreen extends StatefulWidget {
  final String code;

  const RacingHostScreen({super.key, required this.code});

  @override
  State<RacingHostScreen> createState() => _RacingHostScreenState();
}

class _RacingHostScreenState extends State<RacingHostScreen> {
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
        child: StreamBuilder<RacingRoom?>(
          stream: _roomService.racingRoomStream(widget.code),
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
                  case RacingStatus.lobby:
                    return _LobbyView(
                      code: widget.code,
                      players: players,
                      loading: _actionInFlight,
                      onStart: players.isEmpty
                          ? null
                          : () => _guardedAction(() async {
                              await SoundService.instance.play(GameSound.start);
                              await _roomService.startRace(widget.code);
                            }),
                    );
                  case RacingStatus.countdown:
                    return _LiveView(
                      room: room,
                      players: players,
                      loading: _actionInFlight,
                      onFinish: players.any((p) => p.finished)
                          ? () => _guardedAction(
                              () => _roomService.finishRacingGame(widget.code),
                            )
                          : null,
                    );
                  case RacingStatus.finished:
                    return RacingResultsView(players: players);
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
            children: [
              for (final p in players)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: bikeSpecFor(p.bike).color,
                    child: Text(bikeSpecFor(p.bike).emoji),
                  ),
                  title: Text(p.name),
                  subtitle: Text(
                    p.bike == null
                        ? 'Choisit sa moto...'
                        : bikeSpecFor(p.bike).name,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onStart,
              child: const Text('Démarrer la course'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveView extends StatelessWidget {
  final RacingRoom room;
  final List<Player> players;
  final bool loading;
  final VoidCallback? onFinish;

  const _LiveView({
    required this.room,
    required this.players,
    required this.loading,
    required this.onFinish,
  });

  List<Player> get _ranked {
    final ranked = [...players]
      ..sort((a, b) {
        if (a.finished != b.finished) return a.finished ? -1 : 1;
        if (a.finished && b.finished) {
          return (a.finishTimeMs ?? 0).compareTo(b.finishTimeMs ?? 0);
        }
        return b.lapsCompleted.compareTo(a.lapsCompleted);
      });
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '🏁 La course est lancée !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '${room.laps} tours',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final p in _ranked)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: bikeSpecFor(p.bike).color,
                      child: Text(bikeSpecFor(p.bike).emoji),
                    ),
                    title: Text(p.name),
                    trailing: Text(
                      p.finished
                          ? '🏁 Arrivé'
                          : '${p.lapsCompleted} / ${room.laps} tours',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Voir les résultats'),
            ),
          ),
        ],
      ),
    );
  }
}
