import 'package:flutter/material.dart';

import '../theme.dart';
import 'create_room_screen.dart';
import 'create_undercover_room_screen.dart';
import 'create_werewolf_room_screen.dart';

/// Lets the host choose which mini-jeu to host before creating a room.
/// Every mini-game added to the app should get an entry here.
class CreateGamePickerScreen extends StatelessWidget {
  const CreateGamePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisis un mini-jeu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GameCard(
              emoji: '🧠',
              title: 'Quiz Élimination',
              subtitle: 'Réponds vite et bien, une erreur t\'élimine jusqu\'au dernier survivant.',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _GameCard(
              emoji: '🕵️',
              title: 'Undercover',
              subtitle: 'Chacun a un mot secret, un seul groupe a un mot différent. Trouve les infiltrés !',
              color: AppColors.danger,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateUndercoverRoomScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _GameCard(
              emoji: '🐺',
              title: 'Loup-Garou',
              subtitle: 'L\'appli mène la partie : nuits, votes, pouvoirs secrets. Choisis les cartes et joue toi aussi !',
              color: Colors.orangeAccent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateWerewolfRoomScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
