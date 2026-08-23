import 'package:flutter/material.dart';

import '../data/bike_specs.dart';
import '../models/player.dart';
import '../theme.dart';
import 'banner_ad_widget.dart';
import 'staggered_fade_in.dart';

/// Final standings for the racing mini-game: finishers ranked by time,
/// then whoever didn't finish ranked by laps completed.
class RacingResultsView extends StatelessWidget {
  final List<Player> players;
  final String? highlightUid;

  const RacingResultsView({
    super.key,
    required this.players,
    this.highlightUid,
  });

  List<Player> get _ranked {
    final ranked = [...players]
      ..sort((a, b) {
        if (a.finished != b.finished) return a.finished ? -1 : 1;
        if (a.finished && b.finished) {
          return (a.finishTimeMs ?? 0).compareTo(b.finishTimeMs ?? 0);
        }
        return b.lapsCompleted.compareTo(a.lapsCompleted);
      });
    return ranked;
  }

  String _formatTime(int? ms) {
    if (ms == null) return '--';
    final totalSeconds = ms / 1000;
    final minutes = (totalSeconds ~/ 60);
    final seconds = totalSeconds - minutes * 60;
    return '${minutes}m ${seconds.toStringAsFixed(1)}s';
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

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked;
    final winner = ranked.where((p) => p.finished).firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: const Text(
              '🏁 Résultats',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            winner == null
                ? 'Course terminée !'
                : '${winner.name} remporte la course !',
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
                final bike = bikeSpecFor(player.bike);
                return StaggeredFadeIn(
                  delay: Duration(milliseconds: 60 * index),
                  child: ListTile(
                    tileColor: isMe ? AppColors.surface : null,
                    leading: CircleAvatar(
                      backgroundColor: _medalColor(index) ?? bike.color,
                      child: Text(bike.emoji),
                    ),
                    title: Text(
                      isMe ? '${player.name} (toi)' : player.name,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.bold : null,
                      ),
                    ),
                    subtitle: Text(bike.name),
                    trailing: Text(
                      player.finished
                          ? _formatTime(player.finishTimeMs)
                          : '${player.lapsCompleted} tour(s)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
