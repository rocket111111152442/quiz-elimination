import 'package:flutter/material.dart';

class BikeSpec {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final double maxSpeed;
  final double acceleration;
  final double turnRate;

  const BikeSpec({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.maxSpeed,
    required this.acceleration,
    required this.turnRate,
  });
}

const List<BikeSpec> bikeSpecs = [
  BikeSpec(
    id: 'eclair',
    name: 'Éclair',
    emoji: '⚡',
    color: Color(0xFFE0355B),
    maxSpeed: 620,
    acceleration: 260,
    turnRate: 2.6,
  ),
  BikeSpec(
    id: 'equilibree',
    name: 'Équilibrée',
    emoji: '🏍️',
    color: Color(0xFF3B82F6),
    maxSpeed: 520,
    acceleration: 320,
    turnRate: 3.0,
  ),
  BikeSpec(
    id: 'costaud',
    name: 'Costaud',
    emoji: '💪',
    color: Color(0xFF22C55E),
    maxSpeed: 440,
    acceleration: 380,
    turnRate: 2.4,
  ),
  BikeSpec(
    id: 'agile',
    name: 'Agile',
    emoji: '🌀',
    color: Color(0xFFA855F7),
    maxSpeed: 480,
    acceleration: 300,
    turnRate: 3.8,
  ),
];

BikeSpec bikeSpecFor(String? id) =>
    bikeSpecs.firstWhere((b) => b.id == id, orElse: () => bikeSpecs[1]);
