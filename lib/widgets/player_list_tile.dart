import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme.dart';

class PlayerListTile extends StatelessWidget {
  final Player player;
  final Widget? trailing;

  const PlayerListTile({super.key, required this.player, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: player.alive
            ? AppColors.primary
            : Colors.grey.shade700,
        child: Text(
          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
        ),
      ),
      title: Text(
        player.name,
        style: TextStyle(
          color: player.alive ? Colors.white : Colors.white54,
          decoration: player.alive ? null : TextDecoration.lineThrough,
        ),
      ),
      trailing: trailing,
    );
  }
}
