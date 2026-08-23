enum UnoStatus { lobby, playing, finished }

UnoStatus unoStatusFromString(String value) {
  return UnoStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => UnoStatus.lobby,
  );
}

class UnoRoom {
  final String code;
  final String hostUid;
  final UnoStatus status;
  final List<String> playerOrder;
  final int currentPlayerIndex;
  final int direction;
  final String topCardCode;
  final String currentColor;
  final List<String> deckOrder;
  final int drawIndex;
  final String? unoCallUid;
  final bool unoCalled;
  final bool hasDrawnThisTurn;
  final String? winner;

  const UnoRoom({
    required this.code,
    required this.hostUid,
    required this.status,
    required this.playerOrder,
    required this.currentPlayerIndex,
    required this.direction,
    required this.topCardCode,
    required this.currentColor,
    required this.deckOrder,
    required this.drawIndex,
    this.unoCallUid,
    required this.unoCalled,
    required this.hasDrawnThisTurn,
    this.winner,
  });

  String? get currentTurnUid =>
      currentPlayerIndex >= 0 && currentPlayerIndex < playerOrder.length
      ? playerOrder[currentPlayerIndex]
      : null;

  int get cardsLeftInDeck =>
      (deckOrder.length - drawIndex).clamp(0, deckOrder.length);

  factory UnoRoom.fromMap(String code, Map<String, dynamic> map) => UnoRoom(
    code: code,
    hostUid: map['hostUid'] as String,
    status: unoStatusFromString(map['status'] as String? ?? 'lobby'),
    playerOrder: List<String>.from(map['playerOrder'] as List? ?? []),
    currentPlayerIndex: (map['currentPlayerIndex'] as num?)?.toInt() ?? 0,
    direction: (map['direction'] as num?)?.toInt() ?? 1,
    topCardCode: map['topCardCode'] as String? ?? '',
    currentColor: map['currentColor'] as String? ?? 'red',
    deckOrder: List<String>.from(map['deckOrder'] as List? ?? []),
    drawIndex: (map['drawIndex'] as num?)?.toInt() ?? 0,
    unoCallUid: map['unoCallUid'] as String?,
    unoCalled: map['unoCalled'] as bool? ?? false,
    hasDrawnThisTurn: map['hasDrawnThisTurn'] as bool? ?? false,
    winner: map['winner'] as String?,
  );
}
