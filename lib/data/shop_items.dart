import 'package:flutter/material.dart';

/// Name of the in-app currency, shown everywhere points are mentioned.
const currencyName = 'Étincelles';
const currencyNameSingular = 'Étincelle';
const currencyEmoji = '✨';

/// Points earned for winning a game = this × the number of players who
/// were in that game — the bigger the room you beat, the more you earn.
const pointsPerPlayerOnWin = 10;

/// Points earned for watching a rewarded ad all the way through.
const pointsPerAdWatched = 10;

class ShopAvatar {
  final String emoji;
  final int cost;
  const ShopAvatar(this.emoji, this.cost);
}

class ShopColorOption {
  /// Hex string without the leading '#' or alpha channel (e.g. 'E0355B') —
  /// this is exactly what's stored as the player's `colorHex`.
  final String hex;
  final Color color;
  final int cost;
  const ShopColorOption(this.hex, this.color, this.cost);
}

const shopAvatars = [
  ShopAvatar('🎩', 100),
  ShopAvatar('🦊', 100),
  ShopAvatar('🐺', 100),
  ShopAvatar('🃏', 100),
  ShopAvatar('👑', 250),
  ShopAvatar('🎯', 250),
  ShopAvatar('🚀', 250),
  ShopAvatar('🍀', 250),
  ShopAvatar('🏆', 500),
  ShopAvatar('💎', 500),
  ShopAvatar('🐉', 500),
  ShopAvatar('⚡', 500),
];

const shopColors = [
  ShopColorOption('E0355B', Color(0xFFE0355B), 100),
  ShopColorOption('2A7FE0', Color(0xFF2A7FE0), 100),
  ShopColorOption('2AE07A', Color(0xFF2AE07A), 100),
  ShopColorOption('E0A22A', Color(0xFFE0A22A), 100),
  ShopColorOption('E02AA8', Color(0xFFE02AA8), 250),
  ShopColorOption('2AD9E0', Color(0xFF2AD9E0), 250),
  ShopColorOption('E0DD2A', Color(0xFFE0DD2A), 250),
  ShopColorOption('FFD700', Color(0xFFFFD700), 500),
];

/// Consumable point packs sold through the Play Store once the app is
/// published — the product IDs here must match what's configured in the
/// Play Console (Monetize > Products > In-app products) exactly.
class PointsPack {
  final String productId;
  final int points;
  final String label;
  const PointsPack(this.productId, this.points, this.label);
}

const pointsPacks = [
  PointsPack('etincelles_500', 500, 'Petit sachet'),
  PointsPack('etincelles_1500', 1500, 'Sachet moyen'),
  PointsPack('etincelles_5000', 5000, 'Grand sachet'),
];
