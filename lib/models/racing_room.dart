import 'package:cloud_firestore/cloud_firestore.dart';

enum RacingStatus { lobby, countdown, finished }

RacingStatus racingStatusFromString(String value) {
  return RacingStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => RacingStatus.lobby,
  );
}

/// The countdown before the green light, in seconds. Every client derives
/// the exact same race start instant from [RacingRoom.countdownStartedAt]
/// plus this duration, so no further Firestore write is needed once the
/// race is actually rolling — clients simply compare `DateTime.now()`
/// against that instant locally.
const int racingCountdownSeconds = 3;

class RacingRoom {
  final String code;
  final String hostUid;
  final RacingStatus status;
  final int laps;
  final DateTime? countdownStartedAt;

  const RacingRoom({
    required this.code,
    required this.hostUid,
    required this.status,
    required this.laps,
    this.countdownStartedAt,
  });

  DateTime? get raceStartsAt =>
      countdownStartedAt?.add(const Duration(seconds: racingCountdownSeconds));

  factory RacingRoom.fromMap(String code, Map<String, dynamic> map) =>
      RacingRoom(
        code: code,
        hostUid: map['hostUid'] as String,
        status: racingStatusFromString(map['status'] as String? ?? 'lobby'),
        laps: (map['laps'] as num?)?.toInt() ?? 3,
        countdownStartedAt: (map['countdownStartedAt'] as Timestamp?)?.toDate(),
      );
}

class CarPosition {
  final double x;
  final double y;
  final double heading;

  const CarPosition({required this.x, required this.y, this.heading = 0});
}
