import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// How long a player can stay inactive before being auto-eliminated, across
/// every game.
const inactivityLimitSeconds = 150;

/// Small "temps restant avant élimination" pill meant to sit unobtrusively
/// at the top of a game screen — unlike [CountdownTimer] this is a compact
/// badge, not a big ring, since it's a background safety net rather than
/// the main thing the player is looking at.
class InactivityBadge extends StatefulWidget {
  final DateTime since;
  final int durationSeconds;
  final VoidCallback? onExpired;

  const InactivityBadge({
    super.key,
    required this.since,
    this.durationSeconds = inactivityLimitSeconds,
    this.onExpired,
  });

  @override
  State<InactivityBadge> createState() => _InactivityBadgeState();
}

class _InactivityBadgeState extends State<InactivityBadge> {
  late final Timer _ticker;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  int get _remainingSeconds {
    final elapsed = DateTime.now().difference(widget.since).inSeconds;
    return (widget.durationSeconds - elapsed).clamp(0, widget.durationSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingSeconds;
    if (remaining == 0 && !_expiredFired) {
      _expiredFired = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onExpired?.call(),
      );
    }
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final urgent = remaining <= 30;
    final color = urgent ? AppColors.danger : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
