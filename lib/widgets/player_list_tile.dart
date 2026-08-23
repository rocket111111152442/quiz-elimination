import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme.dart';

class PlayerListTile extends StatelessWidget {
  final Player player;
  final Widget? trailing;

  const PlayerListTile({super.key, required this.player, this.trailing});

  @override
  Widget build(BuildContext context) {
    final customColor = player.colorHex != null
        ? Color(int.parse('FF${player.colorHex}', radix: 16))
        : null;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: player.alive
            ? (customColor ?? AppColors.primary)
            : Colors.grey.shade700,
        child: player.avatar != null
            ? Text(player.avatar!, style: const TextStyle(fontSize: 18))
            : Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?'),
      ),
      title: Text(
        player.name,
        style: TextStyle(
          color: player.alive ? (customColor ?? Colors.white) : Colors.white54,
          decoration: player.alive ? null : TextDecoration.lineThrough,
        ),
      ),
      trailing: trailing,
    );
  }
}
