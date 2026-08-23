import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/room_service.dart';
import '../theme.dart';
import 'banner_ad_widget.dart';
import 'staggered_fade_in.dart';

/// Final reveal screen for Undercover: everyone's role, and both secret
/// words. Shared by the host and player screens once the round of play
/// finishes.
class UndercoverResultsView extends StatelessWidget {
  final String code;
  final List<Player> players;
  final String? highlightUid;
  final RoomService roomService;

  const UndercoverResultsView({
    super.key,
    required this.code,
    required this.players,
    required this.roomService,
    this.highlightUid,
  });

  @override
  Widget build(BuildContext context) {
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
              '🕵️ Résultats',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Map<String, dynamic>?>(
            stream: roomService.gameWordsStream(code),
            builder: (context, snap) {
              final words = snap.data;
              if (words == null) return const SizedBox.shrink();
              return Column(
                children: [
                  Text(
                    'Catégorie : ${words['category']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      Chip(
                        label: Text('Civils : ${words['civilWord']}'),
                        backgroundColor: AppColors.success,
                      ),
                      Chip(
                        label: Text('Undercover : ${words['undercoverWord']}'),
                        backgroundColor: AppColors.danger,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<Map<String, String>>(
              stream: roomService.allRolesStream(code),
              builder: (context, roleSnap) {
                final roles = roleSnap.data ?? {};
                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final isMe = player.uid == highlightUid;
                    final role = roles[player.uid];
                    final isUndercover = role == 'undercover';
                    final isMisterWhite = role == 'mister_white';
                    final badgeColor = isUndercover
                        ? AppColors.danger
                        : isMisterWhite
                        ? Colors.amber
                        : AppColors.success;
                    final badgeLabel = isUndercover
                        ? 'Undercover'
                        : isMisterWhite
                        ? 'Mister White'
                        : 'Civil';
                    final badgeIcon = isUndercover
                        ? Icons.theater_comedy
                        : isMisterWhite
                        ? Icons.help_outline
                        : Icons.check_circle_outline;
                    return StaggeredFadeIn(
                      delay: Duration(milliseconds: 60 * index),
                      child: ListTile(
                        tileColor: isMe ? AppColors.surface : null,
                        leading: CircleAvatar(
                          backgroundColor: badgeColor,
                          child: Icon(badgeIcon, size: 18),
                        ),
                        title: Text(
                          isMe ? '${player.name} (toi)' : player.name,
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.bold : null,
                          ),
                        ),
                        trailing: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
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
