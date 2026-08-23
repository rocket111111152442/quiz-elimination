import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/bike_specs.dart';
import '../game/race_track.dart';
import '../models/player.dart';
import '../models/racing_room.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/racing_results_view.dart';

/// The whole racing mini-game for a player: bike pick in the lobby, a
/// countdown, then a live top-down race rendered with a plain
/// [CustomPainter] driven by a [Ticker] — no external game engine, so
/// there's nothing new to fetch or configure on the user's machine.
///
/// Physics run locally for the player's own car (client-authoritative —
/// fine for a fun class game, not a competitive one) and get throttled
/// to Firestore a few times a second; opponents are drawn from their last
/// synced position. The mini-boss's position is a deterministic function
/// of elapsed race time, so every client draws it in the same place
/// without needing to sync it at all.
class RacingPlayerScreen extends StatefulWidget {
  final String code;

  const RacingPlayerScreen({super.key, required this.code});

  @override
  State<RacingPlayerScreen> createState() => _RacingPlayerScreenState();
}

class _RacingPlayerScreenState extends State<RacingPlayerScreen>
    with SingleTickerProviderStateMixin {
  final _roomService = RoomService();
  final _authService = AuthService();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  StreamSubscription<Map<String, CarPosition>>? _positionsSub;
  Map<String, CarPosition> _remotePositions = {};

  RacingRoom? _room;
  List<Player> _players = [];

  bool _physicsStarted = false;
  double _x = 0, _y = 0, _heading = 0, _speed = 0;
  int _nextWaypointIndex = 1;
  int _lapsCompleted = 0;
  bool _finished = false;
  DateTime? _lastSyncedAt;

  bool _steerLeft = false;
  bool _steerRight = false;
  bool _throttle = false;

  String get _uid => _authService.currentUid!;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _positionsSub = _roomService.positionsStream(widget.code).listen((pos) {
      _remotePositions = pos;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _positionsSub?.cancel();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final room = _room;
    if (room == null || room.status != RacingStatus.countdown) return;
    final startsAt = room.raceStartsAt;
    if (startsAt == null) return;
    final now = DateTime.now();
    if (now.isBefore(startsAt)) {
      setState(() {});
      return;
    }
    if (!_physicsStarted) {
      _initPhysics();
      _physicsStarted = true;
    }
    if (!_finished) {
      _stepPhysics(
        dt.clamp(0, 0.05),
        now.difference(startsAt).inMilliseconds / 1000.0,
        room,
      );
    }
    setState(() {});
  }

  void _initPhysics() {
    final sortedUids = [..._players.map((p) => p.uid)]..sort();
    final slot = sortedUids.indexOf(_uid);
    final start =
        RaceTrack.startPositions[slot % RaceTrack.startPositions.length];
    _x = start.x;
    _y = start.y;
    _heading = RaceTrack.startHeading;
    _speed = 0;
    _nextWaypointIndex = 1;
    _lapsCompleted = 0;
    _finished = false;
  }

  void _stepPhysics(double dt, double elapsedRaceSeconds, RacingRoom room) {
    final me = _players.where((p) => p.uid == _uid).firstOrNull;
    final bike = bikeSpecFor(me?.bike);

    if (_steerLeft) _heading -= bike.turnRate * dt;
    if (_steerRight) _heading += bike.turnRate * dt;

    var slowFactor = 1.0;
    for (final obstacle in RaceTrack.obstacles) {
      if (Vec2(_x, _y).distanceTo(obstacle.position) <
          obstacle.radius + RaceTrack.carRadius) {
        slowFactor = 0.4;
      }
    }
    final bossPos = RaceTrack.bossPositionAt(elapsedRaceSeconds);
    final toBoss = Vec2(_x, _y) - bossPos;
    if (toBoss.length < RaceTrack.bossRadius + RaceTrack.carRadius) {
      slowFactor = 0.25;
      if (toBoss.length > 1) {
        final push = toBoss * (220 * dt / toBoss.length);
        _x += push.x;
        _y += push.y;
      }
    }

    if (_throttle) {
      _speed += bike.acceleration * dt;
    } else {
      _speed -= bike.acceleration * 1.4 * dt;
    }
    _speed = _speed.clamp(0, bike.maxSpeed);

    final effectiveSpeed = _speed * slowFactor;
    _x += cos(_heading) * effectiveSpeed * dt;
    _y += sin(_heading) * effectiveSpeed * dt;
    _x = _x.clamp(RaceTrack.carRadius, RaceTrack.width - RaceTrack.carRadius);
    _y = _y.clamp(RaceTrack.carRadius, RaceTrack.height - RaceTrack.carRadius);

    final target = RaceTrack.waypoints[_nextWaypointIndex];
    if (Vec2(_x, _y).distanceTo(target) < RaceTrack.waypointRadius) {
      final wasLast = _nextWaypointIndex == RaceTrack.waypointCount - 1;
      _nextWaypointIndex = (_nextWaypointIndex + 1) % RaceTrack.waypointCount;
      if (wasLast) {
        _lapsCompleted++;
        if (_lapsCompleted >= room.laps) {
          _finished = true;
          _roomService.updateLapProgress(
            code: widget.code,
            uid: _uid,
            lapsCompleted: _lapsCompleted,
            finished: true,
            finishTimeMs: (elapsedRaceSeconds * 1000).round(),
          );
        } else {
          _roomService.updateLapProgress(
            code: widget.code,
            uid: _uid,
            lapsCompleted: _lapsCompleted,
          );
        }
      }
    }

    final now = DateTime.now();
    if (_lastSyncedAt == null ||
        now.difference(_lastSyncedAt!) >= const Duration(milliseconds: 120)) {
      _lastSyncedAt = now;
      _roomService.updatePosition(
        code: widget.code,
        uid: _uid,
        x: _x,
        y: _y,
        heading: _heading,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<RacingRoom?>(
          stream: _roomService.racingRoomStream(widget.code),
          builder: (context, roomSnap) {
            _room = roomSnap.data;
            final room = _room;
            if (room == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<Player>>(
              stream: _roomService.playersStream(widget.code),
              builder: (context, playersSnap) {
                _players = playersSnap.data ?? [];
                switch (room.status) {
                  case RacingStatus.lobby:
                    return _BikePickerView(
                      code: widget.code,
                      uid: _uid,
                      players: _players,
                      roomService: _roomService,
                    );
                  case RacingStatus.countdown:
                    return _buildRaceOrCountdown(room);
                  case RacingStatus.finished:
                    return RacingResultsView(
                      players: _players,
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

  Widget _buildRaceOrCountdown(RacingRoom room) {
    final startsAt = room.raceStartsAt;
    final now = DateTime.now();
    if (startsAt == null || now.isBefore(startsAt)) {
      final remaining = startsAt == null
          ? racingCountdownSeconds.toDouble()
          : startsAt.difference(now).inMilliseconds / 1000.0;
      return Center(
        child: Text(
          remaining <= 0.4 ? 'GO !' : '${remaining.ceil()}',
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold),
        ),
      );
    }
    return _RaceView(
      x: _x,
      y: _y,
      heading: _heading,
      elapsedRaceSeconds: now.difference(startsAt).inMilliseconds / 1000.0,
      lapsCompleted: _lapsCompleted,
      totalLaps: room.laps,
      finished: _finished,
      remotePositions: _remotePositions,
      players: _players,
      uid: _uid,
      onSteerLeft: (v) => _steerLeft = v,
      onSteerRight: (v) => _steerRight = v,
      onThrottle: (v) => _throttle = v,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _BikePickerView extends StatelessWidget {
  final String code;
  final String uid;
  final List<Player> players;
  final RoomService roomService;

  const _BikePickerView({
    required this.code,
    required this.uid,
    required this.players,
    required this.roomService,
  });

  @override
  Widget build(BuildContext context) {
    final me = players.where((p) => p.uid == uid).firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Choisis ta moto',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                for (final bike in bikeSpecs)
                  _BikeCard(
                    bike: bike,
                    selected: me?.bike == bike.id,
                    onTap: () => roomService.setBike(
                      code: code,
                      uid: uid,
                      bikeId: bike.id,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            me?.bike == null
                ? 'Choisis une moto pour être prêt !'
                : 'En attente que l\'hôte lance la course...',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _BikeCard extends StatelessWidget {
  final BikeSpec bike;
  final bool selected;
  final VoidCallback onTap;

  const _BikeCard({
    required this.bike,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? bike.color : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(bike.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              bike.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaceView extends StatelessWidget {
  final double x, y, heading, elapsedRaceSeconds;
  final int lapsCompleted, totalLaps;
  final bool finished;
  final Map<String, CarPosition> remotePositions;
  final List<Player> players;
  final String uid;
  final ValueChanged<bool> onSteerLeft;
  final ValueChanged<bool> onSteerRight;
  final ValueChanged<bool> onThrottle;

  const _RaceView({
    required this.x,
    required this.y,
    required this.heading,
    required this.elapsedRaceSeconds,
    required this.lapsCompleted,
    required this.totalLaps,
    required this.finished,
    required this.remotePositions,
    required this.players,
    required this.uid,
    required this.onSteerLeft,
    required this.onSteerRight,
    required this.onThrottle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = min(
          constraints.maxWidth / RaceTrack.width,
          constraints.maxHeight / RaceTrack.height,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RacePainter(
                  scale: scale,
                  x: x,
                  y: y,
                  heading: heading,
                  elapsedRaceSeconds: elapsedRaceSeconds,
                  remotePositions: remotePositions,
                  players: players,
                  uid: uid,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _Hud(
                lapsCompleted: lapsCompleted,
                totalLaps: totalLaps,
                finished: finished,
              ),
            ),
            if (!finished) ...[
              Positioned(
                bottom: 20,
                left: 20,
                child: Row(
                  children: [
                    _ControlButton(
                      icon: Icons.arrow_back,
                      onChanged: onSteerLeft,
                    ),
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: Icons.arrow_forward,
                      onChanged: onSteerRight,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: _ThrottleButton(onChanged: onThrottle),
              ),
            ] else
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '🏁 Arrivé ! En attente des autres...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  final int lapsCompleted;
  final int totalLaps;
  final bool finished;

  const _Hud({
    required this.lapsCompleted,
    required this.totalLaps,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        finished
            ? 'Tour $totalLaps/$totalLaps'
            : 'Tour ${lapsCompleted + 1}/$totalLaps',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _ControlButton({required this.icon, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Icon(icon, size: 36, color: Colors.white),
      ),
    );
  }
}

class _ThrottleButton extends StatelessWidget {
  final ValueChanged<bool> onChanged;

  const _ThrottleButton({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        alignment: Alignment.center,
        child: const Text(
          'GAZ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _RacePainter extends CustomPainter {
  final double scale, x, y, heading, elapsedRaceSeconds;
  final Map<String, CarPosition> remotePositions;
  final List<Player> players;
  final String uid;

  _RacePainter({
    required this.scale,
    required this.x,
    required this.y,
    required this.heading,
    required this.elapsedRaceSeconds,
    required this.remotePositions,
    required this.players,
    required this.uid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final offsetX = (size.width - RaceTrack.width * scale) / 2;
    final offsetY = (size.height - RaceTrack.height * scale) / 2;
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, RaceTrack.width, RaceTrack.height),
      Paint()..color = const Color(0xFF1B7A3D),
    );

    final trackPath = Path()
      ..moveTo(RaceTrack.waypoints.last.x, RaceTrack.waypoints.last.y);
    for (final wp in RaceTrack.waypoints) {
      trackPath.lineTo(wp.x, wp.y);
    }
    trackPath.close();

    canvas.drawPath(
      trackPath,
      Paint()
        ..color = const Color(0xFF3A3A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = RaceTrack.roadWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    final wp0 = RaceTrack.waypoints[0];
    final perp =
        Offset(-sin(RaceTrack.startHeading), cos(RaceTrack.startHeading)) *
        (RaceTrack.roadWidth / 2);
    canvas.drawLine(
      Offset(wp0.x, wp0.y) - perp,
      Offset(wp0.x, wp0.y) + perp,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 10,
    );

    for (final obstacle in RaceTrack.obstacles) {
      canvas.drawCircle(
        obstacle.position.offset,
        obstacle.radius,
        Paint()..color = const Color(0xFF8B5E1F),
      );
      canvas.drawCircle(
        obstacle.position.offset,
        obstacle.radius * 0.55,
        Paint()..color = const Color(0xFF5C3D12),
      );
    }

    final bossPos = RaceTrack.bossPositionAt(elapsedRaceSeconds);
    canvas.drawCircle(
      bossPos.offset,
      RaceTrack.bossRadius,
      Paint()..color = const Color(0xFF7C0A2E),
    );
    _drawEmoji(canvas, '👹', bossPos.offset, 90);

    for (final player in players) {
      if (player.uid == uid) continue;
      final pos = remotePositions[player.uid];
      if (pos == null) continue;
      _drawCar(
        canvas,
        Vec2(pos.x, pos.y),
        pos.heading,
        bikeSpecFor(player.bike).color,
        player.name,
        false,
      );
    }

    final myBike = bikeSpecFor(
      players.where((p) => p.uid == uid).map((p) => p.bike).firstOrNull,
    );
    _drawCar(canvas, Vec2(x, y), heading, myBike.color, 'Toi', true);

    canvas.restore();
  }

  void _drawCar(
    Canvas canvas,
    Vec2 pos,
    double carHeading,
    Color color,
    String label,
    bool isMe,
  ) {
    canvas.save();
    canvas.translate(pos.x, pos.y);
    canvas.rotate(carHeading);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: RaceTrack.carRadius * 2.2,
      height: RaceTrack.carRadius * 1.3,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = color);
    canvas.drawCircle(
      Offset(RaceTrack.carRadius * 0.7, 0),
      10,
      Paint()..color = Colors.white70,
    );
    if (isMe) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white,
      );
    }
    canvas.restore();

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.x - tp.width / 2, pos.y - 60));
  }

  void _drawEmoji(Canvas canvas, String emoji, Offset at, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RacePainter oldDelegate) => true;
}
