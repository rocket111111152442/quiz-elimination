import 'dart:math';
import 'dart:ui';

class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double get length => sqrt(x * x + y * y);
  double distanceTo(Vec2 o) => (this - o).length;
  Offset get offset => Offset(x, y);
}

class TrackObstacle {
  final Vec2 position;
  final double radius;

  const TrackObstacle(this.position, this.radius);
}

/// A simple 10-point oval loop. Lap progress is tracked by proximity to
/// waypoints in order rather than true road-edge collision — much simpler
/// and robust than polygon collision, and plenty for a fun party race.
class RaceTrack {
  RaceTrack._();

  static const double width = 2000;
  static const double height = 1200;
  static const Vec2 center = Vec2(1000, 600);
  static const double radiusX = 780;
  static const double radiusY = 440;
  static const double roadWidth = 280;
  static const double waypointRadius = 140;
  static const int waypointCount = 10;
  static const double carRadius = 40;

  static final List<Vec2> waypoints = List.generate(waypointCount, (i) {
    final angle = -pi / 2 + (2 * pi * i / waypointCount);
    return Vec2(
      center.x + radiusX * cos(angle),
      center.y + radiusY * sin(angle),
    );
  });

  static final double startHeading = _headingBetween(
    waypoints[0],
    waypoints[1],
  );

  /// Grid start positions just behind the finish line, spread across the
  /// road width so cars don't spawn stacked on each other.
  static final List<Vec2> startPositions = List.generate(8, (i) {
    final row = i ~/ 2;
    final col = i % 2;
    final along =
        Vec2(cos(startHeading), sin(startHeading)) * (-100.0 - row * 100);
    final across =
        Vec2(-sin(startHeading), cos(startHeading)) * (col == 0 ? -80.0 : 80.0);
    return waypoints[0] + along + across;
  });

  static final List<TrackObstacle> obstacles = [
    TrackObstacle(_lerpTrack(1, 0.5), 75),
    TrackObstacle(_lerpTrack(3, 0.5), 75),
    TrackObstacle(_lerpTrack(5, 0.4), 75),
    TrackObstacle(_lerpTrack(7, 0.6), 75),
  ];

  // Le mini-boss patrouille en va-et-vient sur une portion du circuit.
  static final Vec2 bossPointA = _lerpTrack(4, 0.1);
  static final Vec2 bossPointB = _lerpTrack(4, 0.9);
  static const double bossPeriodSeconds = 5;
  static const double bossRadius = 95;

  static Vec2 bossPositionAt(double elapsedSeconds) {
    final t = (sin(2 * pi * elapsedSeconds / bossPeriodSeconds) + 1) / 2;
    return bossPointA + (bossPointB - bossPointA) * t;
  }

  static Vec2 _lerpTrack(int fromWaypoint, double t) {
    final a = waypoints[fromWaypoint % waypointCount];
    final b = waypoints[(fromWaypoint + 1) % waypointCount];
    return a + (b - a) * t;
  }

  static double _headingBetween(Vec2 a, Vec2 b) => atan2(b.y - a.y, b.x - a.x);
}
