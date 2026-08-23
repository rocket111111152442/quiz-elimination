enum UndercoverStatus {
  lobby,
  clue,
  voting,
  reveal,
  misterWhiteGuess,
  finished,
}

UndercoverStatus undercoverStatusFromString(String value) {
  return UndercoverStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => UndercoverStatus.lobby,
  );
}

class UndercoverRoom {
  final String code;
  final String hostUid;
  final UndercoverStatus status;
  final String category;
  final int undercoverCount;
  final int roundIndex;
  final List<String> playerOrder;
  final int currentTurnIndex;
  final String? eliminatedThisRound;
  final bool tieThisRound;
  final String? winner;
  final bool includeMisterWhite;

  const UndercoverRoom({
    required this.code,
    required this.hostUid,
    required this.status,
    required this.category,
    required this.undercoverCount,
    required this.roundIndex,
    required this.playerOrder,
    required this.currentTurnIndex,
    this.eliminatedThisRound,
    required this.tieThisRound,
    this.winner,
    this.includeMisterWhite = false,
  });

  String? get currentTurnUid =>
      currentTurnIndex >= 0 && currentTurnIndex < playerOrder.length
      ? playerOrder[currentTurnIndex]
      : null;

  factory UndercoverRoom.fromMap(String code, Map<String, dynamic> map) =>
      UndercoverRoom(
        code: code,
        hostUid: map['hostUid'] as String,
        status: undercoverStatusFromString(map['status'] as String? ?? 'lobby'),
        category: map['category'] as String? ?? 'Aléatoire',
        undercoverCount: (map['undercoverCount'] as num?)?.toInt() ?? 1,
        roundIndex: (map['roundIndex'] as num?)?.toInt() ?? 0,
        playerOrder: List<String>.from(map['playerOrder'] as List? ?? []),
        currentTurnIndex: (map['currentTurnIndex'] as num?)?.toInt() ?? 0,
        eliminatedThisRound: map['eliminatedThisRound'] as String?,
        tieThisRound: map['tieThisRound'] as bool? ?? false,
        winner: map['winner'] as String?,
        includeMisterWhite: map['includeMisterWhite'] as bool? ?? false,
      );
}
