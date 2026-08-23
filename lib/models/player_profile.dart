import 'package:cloud_firestore/cloud_firestore.dart';

/// A device's persistent progress across every game — points earned and
/// cosmetics unlocked, keyed by its stable anonymous Firebase Auth uid so
/// it survives app restarts without needing a real sign-in system.
class PlayerProfile {
  final int points;
  final List<String> unlockedAvatars;
  final List<String> unlockedColors;
  final String? selectedAvatar;
  final String? selectedColor;
  final Timestamp? lastAdRewardAt;

  const PlayerProfile({
    required this.points,
    required this.unlockedAvatars,
    required this.unlockedColors,
    this.selectedAvatar,
    this.selectedColor,
    this.lastAdRewardAt,
  });

  const PlayerProfile.empty()
    : points = 0,
      unlockedAvatars = const [],
      unlockedColors = const [],
      selectedAvatar = null,
      selectedColor = null,
      lastAdRewardAt = null;

  factory PlayerProfile.fromMap(Map<String, dynamic> map) => PlayerProfile(
    points: (map['points'] as num?)?.toInt() ?? 0,
    unlockedAvatars: List<String>.from(map['unlockedAvatars'] as List? ?? []),
    unlockedColors: List<String>.from(map['unlockedColors'] as List? ?? []),
    selectedAvatar: map['selectedAvatar'] as String?,
    selectedColor: map['selectedColor'] as String?,
    lastAdRewardAt: map['lastAdRewardAt'] as Timestamp?,
  );
}
