import 'package:flutter/material.dart';

import '../data/uno_cards.dart';
import '../models/player.dart';
import '../models/uno_room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/inactivity_badge.dart';
import '../widgets/leave_game_button.dart';
import '../widgets/player_list_tile.dart';
import '../widgets/room_qr_code.dart';
import '../widgets/uno_card_widget.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

const _unoColorNames = {
  'red': 'Rouge',
  'yellow': 'Jaune',
  'green': 'Vert',
  'blue': 'Bleu',
};

const _unoColorSwatches = {
  'red': Color(0xFFD32F2F),
  'yellow': Color(0xFFF9A825),
  'green': Color(0xFF2E7D32),
  'blue': Color(0xFF1565C0),
};

/// Single reactive screen driving the whole UNO game for every player,
/// including the host who also plays — a card game is more fun when
/// everyone is at the table, no spectator narrator needed here.
class UnoGameScreen extends StatefulWidget {
  final String code;

  const UnoGameScreen({super.key, required this.code});

  @override
  State<UnoGameScreen> createState() => _UnoGameScreenState();
}

class _UnoGameScreenState extends State<UnoGameScreen> {
  final _roomService = RoomService();
  final _authService = AuthService();
  bool _actionInFlight = false;

  String get _uid => _authService.currentUid!;

  Future<void> _guardedAction(Future<void> Function() action) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  void _exitToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Salle ${widget.code}'),
        actions: [
          StreamBuilder<UnoRoom?>(
            stream: _roomService.unoRoomStream(widget.code),
            builder: (context, roomSnap) {
              if (roomSnap.data?.status != UnoStatus.playing) {
                return const SizedBox.shrink();
              }
              return LeaveGameButton(
                onConfirmed: () => _roomService.leaveUnoGame(widget.code, _uid),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<UnoRoom?>(
          stream: _roomService.unoRoomStream(widget.code),
          builder: (context, roomSnap) {
            final room = roomSnap.data;
            if (room == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<Player>>(
              stream: _roomService.playersStream(widget.code),
              builder: (context, playersSnap) {
                final players = playersSnap.data ?? [];
                final isHost = room.hostUid == _uid;

                switch (room.status) {
                  case UnoStatus.lobby:
                    return _LobbyView(
                      code: widget.code,
                      players: players,
                      isHost: isHost,
                      loading: _actionInFlight,
                      onStart: () => _guardedAction(
                        () => _roomService.startUnoGame(widget.code),
                      ),
                    );
                  case UnoStatus.playing:
                    return _PlayingView(
                      code: widget.code,
                      room: room,
                      players: players,
                      uid: _uid,
                      roomService: _roomService,
                    );
                  case UnoStatus.finished:
                    return _FinishedView(
                      room: room,
                      players: players,
                      uid: _uid,
                      onExit: _exitToHome,
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
  final bool isHost;
  final bool loading;
  final VoidCallback onStart;

  const _LobbyView({
    required this.code,
    required this.players,
    required this.isHost,
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
        if (isHost) ...[const SizedBox(height: 12), RoomQrCode(code: code)],
        const SizedBox(height: 12),
        Text('${players.length} joueur(s) connecté(s)'),
        Expanded(
          child: ListView(
            children: [for (final p in players) PlayerListTile(player: p)],
          ),
        ),
        if (isHost)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading || players.length < 2 ? null : onStart,
                child: const Text('Démarrer la partie'),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'En attente que l\'hôte démarre la partie...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }
}

class _PlayingView extends StatelessWidget {
  final String code;
  final UnoRoom room;
  final List<Player> players;
  final String uid;
  final RoomService roomService;

  const _PlayingView({
    required this.code,
    required this.room,
    required this.players,
    required this.uid,
    required this.roomService,
  });

  Future<void> _playWild(BuildContext context, String cardCode) async {
    final color = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choisis une couleur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final entry in _unoColorSwatches.entries)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(entry.key),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: entry.value,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _unoColorNames[entry.key] ?? entry.key,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (color == null) return;
    await roomService.playUnoCard(
      code: code,
      uid: uid,
      cardCode: cardCode,
      chosenColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameByUid = {for (final p in players) p.uid: p.name};
    final isMyTurn = room.currentTurnUid == uid;
    final topCard = room.topCardCode.isEmpty
        ? null
        : UnoCard.fromCode(room.topCardCode);
    final me = players.where((p) => p.uid == uid).firstOrNull;
    final eliminated = me != null && !me.alive;

    if (eliminated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '💀 Tu as été retiré pour inactivité.\n'
            'Regarde la suite de la partie !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (room.turnStartedAt != null)
          Align(
            alignment: Alignment.centerRight,
            child: InactivityBadge(
              since: room.turnStartedAt!.toDate(),
              onExpired: () => roomService.resolveUnoInactivity(
                code,
                room.turnStartedAt!.toDate(),
              ),
            ),
          ),
        const SizedBox(height: 8),
        StreamBuilder<Map<String, int>>(
          stream: roomService.unoHandCountsStream(code),
          builder: (context, countsSnap) {
            final counts = countsSnap.data ?? {};
            final others = room.playerOrder.where((u) => u != uid).toList();
            final unoNames = counts.entries
                .where((e) => e.value == 1)
                .map((e) => nameByUid[e.key] ?? '...')
                .toList();
            return Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final otherUid in others)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: otherUid == room.currentTurnUid
                              ? AppColors.primary
                              : AppColors.surface,
                          child: Text('${counts[otherUid] ?? 0}'),
                        ),
                        label: Text(nameByUid[otherUid] ?? '...'),
                      ),
                  ],
                ),
                if (unoNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '🃏 ${unoNames.join(' et ')} ${unoNames.length > 1 ? 'ont' : 'a'} UNO !',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          isMyTurn
              ? 'C\'est ton tour !'
              : 'Tour de ${nameByUid[room.currentTurnUid] ?? '...'}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isMyTurn ? AppColors.success : Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            UnoCardWidget(),
            const SizedBox(width: 24),
            UnoCardWidget(card: topCard),
            const SizedBox(width: 16),
            Column(
              children: [
                const Text(
                  'Couleur',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _unoColorSwatches[room.currentColor],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${room.cardsLeftInDeck} carte(s) dans la pioche',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const Spacer(),
        StreamBuilder<List<String>>(
          stream: roomService.myUnoHandStream(code, uid),
          builder: (context, handSnap) {
            final hand = (handSnap.data ?? []).map(UnoCard.fromCode).toList();
            final topValue = topCard?.value ?? '';
            return SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final card in hand)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: UnoCardWidget(
                        card: card,
                        disabled:
                            !isMyTurn ||
                            !isUnoCardPlayable(
                              card,
                              room.currentColor,
                              topValue,
                            ),
                        onTap: () {
                          if (card.isWild) {
                            _playWild(context, card.code);
                          } else {
                            roomService.playUnoCard(
                              code: code,
                              uid: uid,
                              cardCode: card.code,
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isMyTurn && !room.hasDrawnThisTurn
                      ? () => roomService.drawUnoCard(code: code, uid: uid)
                      : null,
                  child: const Text('Piocher'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isMyTurn && room.hasDrawnThisTurn
                      ? () => roomService.passUnoTurn(code: code, uid: uid)
                      : null,
                  child: const Text('Passer'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FinishedView extends StatelessWidget {
  final UnoRoom room;
  final List<Player> players;
  final String uid;
  final VoidCallback onExit;

  const _FinishedView({
    required this.room,
    required this.players,
    required this.uid,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final winnerName = players
        .where((p) => p.uid == room.winner)
        .map((p) => p.name)
        .firstOrNull;
    final isMe = room.winner == uid;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Text(
              isMe ? '🏆 Tu as gagné !' : '🏆 ${winnerName ?? '...'} gagne !',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onExit,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Quitter la partie'),
            ),
          ),
        ],
      ),
    );
  }
}
