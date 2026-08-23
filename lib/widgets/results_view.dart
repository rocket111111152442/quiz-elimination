import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme.dart';
import 'banner_ad_widget.dart';

/// Shared final leaderboard, used by both the host and player screens so
/// the ranking logic only lives in one place.
class ResultsView extends StatelessWidget {
  final List<Player> players;
  final String? highlightUid;

  const ResultsView({super.key, required this.players, this.highlightUid});

  List<Player> get _ranked {
    final ranked = [...players]
      ..sort((a, b) {
        if (a.alive != b.alive) return a.alive ? -1 : 1;
        final ea = a.eliminatedAtQuestion ?? -1;
        final eb = b.eliminatedAtQuestion ?? -1;
        return eb.compareTo(ea);
      });
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked;
    final winners = ranked.where((p) => p.alive).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '🏆 Résultats',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            winners.isEmpty
                ? 'Personne n\'a survécu, quelle partie !'
                : winners.length == 1
                ? '${winners.first.name} remporte la partie !'
                : '${winners.map((p) => p.name).join(", ")} terminent premiers ex æquo !',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: ranked.length,
              itemBuilder: (context, index) {
                final player = ranked[index];
                final isMe = player.uid == highlightUid;
                return ListTile(
                  tileColor: isMe ? AppColors.surface : null,
                  leading: CircleAvatar(
                    backgroundColor: _medalColor(index) ?? AppColors.surface,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    isMe ? '${player.name} (toi)' : player.name,
                    style: TextStyle(fontWeight: isMe ? FontWeight.bold : null),
                  ),
                  trailing: player.alive
                      ? const Icon(Icons.emoji_events, color: Colors.amber)
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Color? _medalColor(int rank) {
    switch (rank) {
      case 0:
        return const Color(0xFFD4AF37);
      case 1:
        return const Color(0xFFB0B7BD);
      case 2:
        return const Color(0xFFCD7F32);
      default:
        return null;
    }
  }
}
