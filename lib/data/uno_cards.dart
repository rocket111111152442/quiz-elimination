enum UnoColor { red, yellow, green, blue, wild }

/// A single UNO card. [value] is '0'-'9' for number cards, or one of
/// 'skip', 'reverse', 'drawTwo', 'wild', 'wildDrawFour'.
class UnoCard {
  final UnoColor color;
  final String value;

  const UnoCard({required this.color, required this.value});

  bool get isWild => color == UnoColor.wild;
  bool get isNumber => int.tryParse(value) != null;

  /// Compact string form used to store cards in Firestore lists.
  String get code => '${color.name}:$value';

  factory UnoCard.fromCode(String code) {
    final parts = code.split(':');
    return UnoCard(color: UnoColor.values.byName(parts[0]), value: parts[1]);
  }

  static const _symbolLabels = {
    'skip': '⛔',
    'reverse': '🔄',
    'drawTwo': '+2',
    'wild': '🌈',
    'wildDrawFour': '+4',
  };

  String get label => isNumber ? value : (_symbolLabels[value] ?? value);
}

/// A standard 108-card UNO deck: for each of the 4 colors, one 0, two
/// each of 1-9, two Skip, two Reverse, two Draw Two (25×4 = 100) — plus
/// 4 Wild and 4 Wild Draw Four (8) = 108 total.
List<UnoCard> buildFullUnoDeck() {
  final cards = <UnoCard>[];
  for (final color in [
    UnoColor.red,
    UnoColor.yellow,
    UnoColor.green,
    UnoColor.blue,
  ]) {
    cards.add(UnoCard(color: color, value: '0'));
    for (var n = 1; n <= 9; n++) {
      cards.add(UnoCard(color: color, value: '$n'));
      cards.add(UnoCard(color: color, value: '$n'));
    }
    for (var i = 0; i < 2; i++) {
      cards.add(UnoCard(color: color, value: 'skip'));
      cards.add(UnoCard(color: color, value: 'reverse'));
      cards.add(UnoCard(color: color, value: 'drawTwo'));
    }
  }
  for (var i = 0; i < 4; i++) {
    cards.add(const UnoCard(color: UnoColor.wild, value: 'wild'));
    cards.add(const UnoCard(color: UnoColor.wild, value: 'wildDrawFour'));
  }
  return cards;
}

/// Whether [card] can legally be played on top of a discard pile showing
/// [topColor] (the active color — for a wild top card this is whatever
/// color was chosen, never 'wild' itself) and [topValue].
bool isUnoCardPlayable(UnoCard card, String topColor, String topValue) {
  if (card.isWild) return true;
  if (card.color.name == topColor) return true;
  if (card.value == topValue) return true;
  return false;
}
