import 'package:flutter/material.dart';

import '../data/werewolf_roles.dart';
import '../models/player.dart';
import '../models/werewolf_room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/inactivity_badge.dart';
import '../widgets/leave_game_button.dart';
import '../widgets/player_list_tile.dart';
import '../widgets/room_qr_code.dart';
import '../widgets/staggered_fade_in.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Single reactive screen driving the whole Loup-Garou game, used by
/// EVERY player including the host — the host also plays here, unlike
/// the quiz/Undercover hosts who only spectate. The app itself is the
/// narrator: night phases advance automatically as roles submit their
/// actions, only the day phases (open vote / close vote) are host-paced.
class WerewolfGameScreen extends StatefulWidget {
  final String code;

  const WerewolfGameScreen({super.key, required this.code});

  @override
  State<WerewolfGameScreen> createState() => _WerewolfGameScreenState();
}

class _WerewolfGameScreenState extends State<WerewolfGameScreen> {
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
        title: Text('Salle ${widget.code}'),
        actions: [
          StreamBuilder<WerewolfRoom?>(
            stream: _roomService.werewolfRoomStream(widget.code),
            builder: (context, roomSnap) {
              final status = roomSnap.data?.status;
              if (status == null ||
                  status == WerewolfStatus.lobby ||
                  status == WerewolfStatus.finished) {
                return const SizedBox.shrink();
              }
              return LeaveGameButton(
                onConfirmed: () =>
                    _roomService.leaveWerewolfGame(widget.code, _uid),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<WerewolfRoom?>(
          stream: _roomService.werewolfRoomStream(widget.code),
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
                final isHost = room.hostUid == _uid;
                final nameByUid = {for (final p in players) p.uid: p.name};

                switch (room.status) {
                  case WerewolfStatus.lobby:
                    return _LobbyView(
                      code: widget.code,
                      room: room,
                      players: players,
                      isHost: isHost,
                      loading: _actionInFlight,
                      roomService: _roomService,
                      onStart: () => _guardedAction(() async {
                        try {
                          await _roomService.startWerewolfGame(widget.code);
                        } on WerewolfCompositionException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      }),
                    );
                  case WerewolfStatus.night:
                    return _NightView(
                      code: widget.code,
                      room: room,
                      me: me,
                      uid: _uid,
                      nameByUid: nameByUid,
                      players: players,
                      roomService: _roomService,
                    );
                  case WerewolfStatus.hunterRevenge:
                    return _HunterRevengeView(
                      code: widget.code,
                      room: room,
                      uid: _uid,
                      players: players,
                      nameByUid: nameByUid,
                      roomService: _roomService,
                    );
                  case WerewolfStatus.dayReveal:
                    return _DayRevealView(
                      room: room,
                      nameByUid: nameByUid,
                      isHost: isHost,
                      loading: _actionInFlight,
                      onOpenVote: () => _guardedAction(
                        () => _roomService.openWerewolfDayVote(widget.code),
                      ),
                    );
                  case WerewolfStatus.dayVote:
                    return _DayVoteView(
                      code: widget.code,
                      room: room,
                      me: me,
                      uid: _uid,
                      players: players,
                      isHost: isHost,
                      loading: _actionInFlight,
                      roomService: _roomService,
                      onTally: () => _guardedAction(
                        () => _roomService.tallyWerewolfDayVote(widget.code),
                      ),
                    );
                  case WerewolfStatus.voteReveal:
                    return _VoteRevealView(
                      room: room,
                      nameByUid: nameByUid,
                      isHost: isHost,
                      loading: _actionInFlight,
                      onContinue: () => _guardedAction(
                        () => _roomService.startNextWerewolfRound(widget.code),
                      ),
                    );
                  case WerewolfStatus.finished:
                    return _FinishedView(
                      code: widget.code,
                      room: room,
                      players: players,
                      roomService: _roomService,
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

class _LobbyView extends StatefulWidget {
  final String code;
  final WerewolfRoom room;
  final List<Player> players;
  final bool isHost;
  final bool loading;
  final RoomService roomService;
  final VoidCallback onStart;

  const _LobbyView({
    required this.code,
    required this.room,
    required this.players,
    required this.isHost,
    required this.loading,
    required this.roomService,
    required this.onStart,
  });

  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView> {
  late int _loupGarouCount = widget.room.loupGarouCount;
  late final Map<String, bool> _roleEnabled = Map.of(widget.room.roleEnabled);

  void _save() {
    widget.roomService.updateWerewolfComposition(
      code: widget.code,
      loupGarouCount: _loupGarouCount,
      roleEnabled: _roleEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueRoles = werewolfRoles.where((r) => r.isUnique).toList();
    final totalSpecial =
        _loupGarouCount + _roleEnabled.values.where((v) => v).length;
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Code de la partie',
          style: TextStyle(color: Colors.white70),
        ),
        Text(
          widget.code,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        if (widget.isHost) ...[
          const SizedBox(height: 12),
          RoomQrCode(code: widget.code),
        ],
        const SizedBox(height: 8),
        Text('${widget.players.length} joueur(s) connecté(s)'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final p in widget.players) PlayerListTile(player: p),
              const Divider(height: 32),
              if (widget.isHost) ...[
                const Text(
                  'Nombre de Loups-Garous',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _loupGarouCount > 1
                          ? () => setState(() {
                              _loupGarouCount--;
                              _save();
                            })
                          : null,
                    ),
                    Text(
                      '$_loupGarouCount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() {
                        _loupGarouCount++;
                        _save();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cartes spéciales',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in uniqueRoles)
                      FilterChip(
                        label: Text('${role.emoji} ${role.name}'),
                        selected: _roleEnabled[role.id] ?? false,
                        onSelected: (v) => setState(() {
                          _roleEnabled[role.id] = v;
                          _save();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalSpecial carte(s) spéciale(s) pour '
                  '${widget.players.length} joueur(s).',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                if (totalSpecial > widget.players.length)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Trop de cartes pour le nombre de joueurs actuel.',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ] else
                const Text(
                  'En attente que l\'hôte configure la partie...',
                  style: TextStyle(color: Colors.white70),
                ),
            ],
          ),
        ),
        if (widget.isHost)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.loading || widget.players.length < 2
                    ? null
                    : widget.onStart,
                child: const Text('Démarrer la partie'),
              ),
            ),
          ),
      ],
    );
  }
}

class _NightView extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final Player? me;
  final String uid;
  final Map<String, String> nameByUid;
  final List<Player> players;
  final RoomService roomService;

  const _NightView({
    required this.code,
    required this.room,
    required this.me,
    required this.uid,
    required this.nameByUid,
    required this.players,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    final currentRole = room.currentNightRole;
    final roleDef = currentRole != null ? werewolfRoleFor(currentRole) : null;
    final eliminated = me != null && !me!.alive;

    return StreamBuilder<String?>(
      stream: roomService.roleStream(code, uid),
      builder: (context, roleSnap) {
        final myRole = roleSnap.data;
        final isMyTurn =
            !eliminated && currentRole != null && myRole == currentRole;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (room.phaseStartedAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: InactivityBadge(
                    since: room.phaseStartedAt!.toDate(),
                    onExpired: () => roomService.resolveWerewolfInactivity(
                      code,
                      room.phaseStartedAt!.toDate(),
                    ),
                  ),
                ),
              Text(
                '🌙 Nuit ${room.roundIndex + 1}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (roleDef != null)
                Text(
                  '${roleDef.emoji} ${roleDef.name} se réveille...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: eliminated
                    ? const Center(
                        child: Text(
                          '💀 Tu es éliminé.\nTu regardes la partie se '
                          'dérouler...',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      )
                    : isMyTurn
                    ? _buildRoleAction(currentRole)
                    : const Center(
                        child: Text(
                          'Le village dort...',
                          style: TextStyle(fontSize: 16, color: Colors.white54),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleAction(String role) {
    switch (role) {
      case 'loupGarou':
        return _WolfVoteAction(
          code: code,
          room: room,
          uid: uid,
          players: players,
          nameByUid: nameByUid,
          roomService: roomService,
        );
      case 'salvateur':
        return _SalvateurAction(
          code: code,
          room: room,
          uid: uid,
          players: players,
          roomService: roomService,
        );
      case 'voyante':
        return _VoyanteAction(
          code: code,
          room: room,
          uid: uid,
          players: players,
          nameByUid: nameByUid,
          roomService: roomService,
        );
      case 'sorciere':
        return _WitchAction(
          code: code,
          room: room,
          uid: uid,
          players: players,
          nameByUid: nameByUid,
          roomService: roomService,
        );
      case 'cupidon':
        return _CupidonAction(
          code: code,
          uid: uid,
          players: players,
          roomService: roomService,
        );
      case 'petiteFille':
        return _PetiteFilleAction(
          code: code,
          room: room,
          nameByUid: nameByUid,
          roomService: roomService,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _WolfVoteAction extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final String uid;
  final List<Player> players;
  final Map<String, String> nameByUid;
  final RoomService roomService;

  const _WolfVoteAction({
    required this.code,
    required this.room,
    required this.uid,
    required this.players,
    required this.nameByUid,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    final alive = players.where((p) => p.alive).toList();
    return Column(
      children: [
        StreamBuilder<List<String>>(
          stream: roomService.wolfTeammatesStream(code),
          builder: (context, snap) {
            final teammates = (snap.data ?? [])
                .where((u) => u != uid)
                .map((u) => nameByUid[u] ?? '...')
                .toList();
            if (teammates.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Tes camarades loups : ${teammates.join(", ")}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          },
        ),
        const Text(
          'Qui dévorez-vous cette nuit ?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<Map<String, String>>(
            stream: roomService.wolfVotesStream(code, room.roundIndex),
            builder: (context, votesSnap) {
              final votes = votesSnap.data ?? {};
              return ListView(
                children: [
                  for (final p in alive)
                    Card(
                      color: votes[uid] == p.uid
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : null,
                      child: ListTile(
                        title: Text(p.name),
                        trailing: Text(
                          '${votes.values.where((v) => v == p.uid).length} '
                          'vote(s)',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onTap: () => roomService.submitWolfVote(
                          code: code,
                          uid: uid,
                          roundIndex: room.roundIndex,
                          targetUid: p.uid,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SalvateurAction extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final String uid;
  final List<Player> players;
  final RoomService roomService;

  const _SalvateurAction({
    required this.code,
    required this.room,
    required this.uid,
    required this.players,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    final choices = players
        .where((p) => p.alive && p.uid != room.salvateurLastProtectedUid)
        .toList();
    return Column(
      children: [
        const Text(
          'Qui protèges-tu cette nuit ?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final p in choices)
                Card(
                  child: ListTile(
                    title: Text(p.name),
                    trailing: const Icon(Icons.shield_outlined),
                    onTap: () => roomService.submitSalvateurChoice(
                      code: code,
                      uid: uid,
                      roundIndex: room.roundIndex,
                      targetUid: p.uid,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoyanteAction extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final String uid;
  final List<Player> players;
  final Map<String, String> nameByUid;
  final RoomService roomService;

  const _VoyanteAction({
    required this.code,
    required this.room,
    required this.uid,
    required this.players,
    required this.nameByUid,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: roomService.voyanteLookTargetStream(code, room.roundIndex, uid),
      builder: (context, targetSnap) {
        final target = targetSnap.data;
        if (target == null) {
          final choices = players
              .where((p) => p.alive && p.uid != uid)
              .toList();
          return Column(
            children: [
              const Text(
                'Qui veux-tu regarder ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in choices)
                      Card(
                        child: ListTile(
                          title: Text(p.name),
                          trailing: const Icon(Icons.remove_red_eye_outlined),
                          onTap: () => roomService.submitVoyanteLook(
                            code: code,
                            uid: uid,
                            roundIndex: room.roundIndex,
                            targetUid: p.uid,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        return StreamBuilder<String?>(
          stream: roomService.roleStream(code, target),
          builder: (context, roleSnap) {
            final role = roleSnap.data;
            final roleDef = role != null ? werewolfRoleFor(role) : null;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${nameByUid[target] ?? '...'} est :',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (roleDef != null)
                    Text(
                      '${roleDef.emoji} ${roleDef.name}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => roomService.advanceWerewolfNightStep(code),
                    child: const Text('Continuer'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WitchAction extends StatefulWidget {
  final String code;
  final WerewolfRoom room;
  final String uid;
  final List<Player> players;
  final Map<String, String> nameByUid;
  final RoomService roomService;

  const _WitchAction({
    required this.code,
    required this.room,
    required this.uid,
    required this.players,
    required this.nameByUid,
    required this.roomService,
  });

  @override
  State<_WitchAction> createState() => _WitchActionState();
}

class _WitchActionState extends State<_WitchAction> {
  bool _heal = false;
  String? _killTarget;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const Center(
        child: Text('Action envoyée...', style: TextStyle(fontSize: 18)),
      );
    }
    final victimUid = widget.room.werewolfVictimUid;
    final victimName = victimUid != null
        ? (widget.nameByUid[victimUid] ?? '...')
        : null;
    final killChoices = widget.players
        .where((p) => p.alive && p.uid != widget.uid)
        .toList();
    return SingleChildScrollView(
      child: Column(
        children: [
          if (victimName != null) ...[
            Text(
              'Les loups ont choisi $victimName cette nuit.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (!widget.room.witchHealUsed)
              CheckboxListTile(
                value: _heal,
                onChanged: (v) => setState(() => _heal = v ?? false),
                title: Text('Sauver $victimName avec ta potion de vie'),
              )
            else
              const Text(
                'Potion de vie déjà utilisée.',
                style: TextStyle(color: Colors.white54),
              ),
          ] else
            const Text(
              'Les loups n\'ont attaqué personne cette nuit.',
              style: TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 16),
          if (!widget.room.witchKillUsed) ...[
            const Text(
              'Potion de mort (facultatif)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in killChoices)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: _killTarget == p.uid,
                    onSelected: (v) =>
                        setState(() => _killTarget = v ? p.uid : null),
                  ),
              ],
            ),
          ] else
            const Text(
              'Potion de mort déjà utilisée.',
              style: TextStyle(color: Colors.white54),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _submitted = true);
              widget.roomService.submitWitchAction(
                code: widget.code,
                uid: widget.uid,
                roundIndex: widget.room.roundIndex,
                heal: _heal,
                killTargetUid: _killTarget,
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

class _CupidonAction extends StatefulWidget {
  final String code;
  final String uid;
  final List<Player> players;
  final RoomService roomService;

  const _CupidonAction({
    required this.code,
    required this.uid,
    required this.players,
    required this.roomService,
  });

  @override
  State<_CupidonAction> createState() => _CupidonActionState();
}

class _CupidonActionState extends State<_CupidonAction> {
  final Set<String> _selected = {};
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const Center(
        child: Text('Choix envoyé...', style: TextStyle(fontSize: 18)),
      );
    }
    return Column(
      children: [
        const Text(
          'Choisis deux amoureux (toi y compris si tu veux) :',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final p in widget.players.where((p) => p.alive))
                CheckboxListTile(
                  value: _selected.contains(p.uid),
                  title: Text(p.name),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      if (_selected.length < 2) _selected.add(p.uid);
                    } else {
                      _selected.remove(p.uid);
                    }
                  }),
                ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selected.length == 2
                ? () {
                    setState(() => _submitted = true);
                    widget.roomService.submitCupidonChoice(
                      code: widget.code,
                      uid: widget.uid,
                      loverUids: _selected.toList(),
                    );
                  }
                : null,
            child: const Text('Confirmer'),
          ),
        ),
      ],
    );
  }
}

class _PetiteFilleAction extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final Map<String, String> nameByUid;
  final RoomService roomService;

  const _PetiteFilleAction({
    required this.code,
    required this.room,
    required this.nameByUid,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Tu espionnes en secret les Loups-Garous...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        StreamBuilder<Map<String, String>>(
          stream: roomService.wolfVotesStream(code, room.roundIndex),
          builder: (context, snap) {
            final votes = snap.data ?? {};
            if (votes.isEmpty) {
              return const Text(
                'Les loups n\'ont pas encore choisi...',
                style: TextStyle(color: Colors.white54),
              );
            }
            return Column(
              children: [
                for (final entry in votes.entries)
                  Text(
                    '${nameByUid[entry.key] ?? '...'} vote pour '
                    '${nameByUid[entry.value] ?? '...'}',
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => roomService.advanceWerewolfNightStep(code),
          child: const Text('Arrêter d\'espionner'),
        ),
      ],
    );
  }
}

class _HunterRevengeView extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final String uid;
  final List<Player> players;
  final Map<String, String> nameByUid;
  final RoomService roomService;

  const _HunterRevengeView({
    required this.code,
    required this.room,
    required this.uid,
    required this.players,
    required this.nameByUid,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    final isHunter = room.pendingActorUid == uid;
    final badge = room.phaseStartedAt == null
        ? null
        : Align(
            alignment: Alignment.centerRight,
            child: InactivityBadge(
              since: room.phaseStartedAt!.toDate(),
              onExpired: () => roomService.resolveWerewolfInactivity(
                code,
                room.phaseStartedAt!.toDate(),
              ),
            ),
          );
    if (!isHunter) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ?badge,
            Text(
              '🏹 ${nameByUid[room.pendingActorUid] ?? '...'} était Chasseur '
              'et vient de mourir...\nIl/elle choisit sa vengeance.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }
    final choices = players.where((p) => p.alive && p.uid != uid).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ?badge,
          const Text(
            '🏹 Tu es mort, mais avant de partir...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Choisis qui tu emmènes avec toi !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final p in choices)
                  Card(
                    child: ListTile(
                      title: Text(p.name),
                      onTap: () => roomService.submitHunterRevenge(
                        code: code,
                        hunterUid: uid,
                        targetUid: p.uid,
                      ),
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

class _DayRevealView extends StatelessWidget {
  final WerewolfRoom room;
  final Map<String, String> nameByUid;
  final bool isHost;
  final bool loading;
  final VoidCallback onOpenVote;

  const _DayRevealView({
    required this.room,
    required this.nameByUid,
    required this.isHost,
    required this.loading,
    required this.onOpenVote,
  });

  @override
  Widget build(BuildContext context) {
    final deaths = [...room.lastNightDeaths, ...room.chainDeaths];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '☀️ Le village se réveille...',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (deaths.isEmpty)
            const Text(
              'Personne n\'est mort cette nuit !',
              style: TextStyle(fontSize: 18, color: AppColors.success),
            )
          else ...[
            const Text(
              'Ont été retrouvés sans vie :',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            for (final uid in deaths)
              Text(
                nameByUid[uid] ?? '...',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
          ],
          const SizedBox(height: 32),
          if (isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onOpenVote,
                child: const Text('Passer au vote du village'),
              ),
            )
          else
            const Text(
              'En attente que l\'hôte lance le vote...',
              style: TextStyle(color: Colors.white54),
            ),
        ],
      ),
    );
  }
}

class _DayVoteView extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final Player? me;
  final String uid;
  final List<Player> players;
  final bool isHost;
  final bool loading;
  final RoomService roomService;
  final VoidCallback onTally;

  const _DayVoteView({
    required this.code,
    required this.room,
    required this.me,
    required this.uid,
    required this.players,
    required this.isHost,
    required this.loading,
    required this.roomService,
    required this.onTally,
  });

  @override
  Widget build(BuildContext context) {
    final eliminated = me != null && !me!.alive;
    final disenfranchised = room.disenfranchisedUids.contains(uid);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (room.phaseStartedAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: InactivityBadge(
                since: room.phaseStartedAt!.toDate(),
                onExpired: () => roomService.resolveWerewolfInactivity(
                  code,
                  room.phaseStartedAt!.toDate(),
                ),
              ),
            ),
          const Text(
            '🗳️ Qui le village élimine-t-il ?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<Map<String, String>>(
              stream: roomService.werewolfDayVotesStream(code, room.roundIndex),
              builder: (context, snap) {
                final votes = snap.data ?? {};
                if (eliminated || disenfranchised) {
                  return Center(
                    child: Text(
                      eliminated
                          ? '💀 Tu es éliminé, tu regardes le vote.'
                          : 'Tu as perdu ton droit de vote.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  );
                }
                final myVote = votes[uid];
                final choices = players
                    .where((p) => p.alive && p.uid != uid)
                    .toList();
                final eligibleCount = players
                    .where(
                      (p) =>
                          p.alive && !room.disenfranchisedUids.contains(p.uid),
                    )
                    .length;
                return ListView(
                  children: [
                    for (final p in choices)
                      Card(
                        color: myVote == p.uid
                            ? AppColors.danger.withValues(alpha: 0.3)
                            : null,
                        child: ListTile(
                          title: Text(p.name),
                          trailing: Text(
                            '${votes.values.where((v) => v == p.uid).length}',
                          ),
                          onTap: () => roomService.submitWerewolfDayVote(
                            code: code,
                            uid: uid,
                            roundIndex: room.roundIndex,
                            votedFor: p.uid,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '${votes.length} / $eligibleCount ont voté',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                );
              },
            ),
          ),
          if (isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onTally,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Clore le vote'),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoteRevealView extends StatelessWidget {
  final WerewolfRoom room;
  final Map<String, String> nameByUid;
  final bool isHost;
  final bool loading;
  final VoidCallback onContinue;

  const _VoteRevealView({
    required this.room,
    required this.nameByUid,
    required this.isHost,
    required this.loading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (room.lastVoteIdiotSurvived)
            const Text(
              '🤪 C\'était l\'Idiot du Village ! Il/elle survit, révélé(e), '
              'mais perd son droit de vote.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )
          else if (room.lastVoteEliminated == null)
            Text(
              room.lastVoteTie
                  ? 'Égalité ! Personne n\'est éliminé.'
                  : 'Personne n\'a été éliminé.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            )
          else ...[
            Text(
              '${nameByUid[room.lastVoteEliminated] ?? '...'} est éliminé(e) '
              'par le village !',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
            for (final uid in room.chainDeaths)
              Text(
                '${nameByUid[uid] ?? '...'} meurt aussi...',
                style: const TextStyle(color: AppColors.danger),
              ),
          ],
          const SizedBox(height: 32),
          if (isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onContinue,
                child: const Text('Manche suivante'),
              ),
            )
          else
            const Text(
              'En attente de la manche suivante...',
              style: TextStyle(color: Colors.white54),
            ),
        ],
      ),
    );
  }
}

class _FinishedView extends StatelessWidget {
  final String code;
  final WerewolfRoom room;
  final List<Player> players;
  final RoomService roomService;
  final VoidCallback onExit;

  const _FinishedView({
    required this.code,
    required this.room,
    required this.players,
    required this.roomService,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (room.winner) {
      'village' => '🎉 Le village gagne !',
      'loups' => '🐺 Les Loups-Garous gagnent !',
      'amoureux' => '💘 Les amoureux gagnent !',
      _ => 'Partie terminée',
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<Map<String, String>>(
              stream: roomService.allRolesStream(code),
              builder: (context, snap) {
                final roles = snap.data ?? {};
                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final role = roles[player.uid];
                    final roleDef = role != null ? werewolfRoleFor(role) : null;
                    return StaggeredFadeIn(
                      delay: Duration(milliseconds: 60 * index),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(roleDef?.emoji ?? '❓'),
                        ),
                        title: Text(player.name),
                        subtitle: Text(player.alive ? 'Survivant' : 'Éliminé'),
                        trailing: Text(
                          roleDef?.name ?? '...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const BannerAdWidget(),
          const SizedBox(height: 12),
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
