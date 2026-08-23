import 'package:flutter/material.dart';

import '../theme.dart';

/// Small "Quitter la partie" action with a confirmation dialog, since
/// leaving mid-game eliminates the player immediately and can't be
/// undone.
class LeaveGameButton extends StatelessWidget {
  final VoidCallback onConfirmed;

  const LeaveGameButton({super.key, required this.onConfirmed});

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Quitter la partie ?'),
        content: const Text(
          'Tu seras éliminé(e) immédiatement et ne pourras pas revenir '
          'dans cette partie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.exit_to_app),
      tooltip: 'Quitter la partie',
      onPressed: () => _confirm(context),
    );
  }
}
