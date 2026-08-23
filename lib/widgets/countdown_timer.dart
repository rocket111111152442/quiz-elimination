import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../theme.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime startedAt;
  final int durationSeconds;
  final VoidCallback? onExpired;

  const CountdownTimer({
    super.key,
    required this.startedAt,
    required this.durationSeconds,
    this.onExpired,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _ticker;
  bool _expiredFired = false;
  int? _lastTickedSecond;

  @override
  void initState() {
    super.initState();
    // Ticks faster than once a second so the progress ring animates
    // smoothly instead of jumping.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  double get _remainingMillis {
    final elapsed = DateTime.now().difference(widget.startedAt).inMilliseconds;
    final totalMillis = widget.durationSeconds * 1000;
    return (totalMillis - elapsed).clamp(0, totalMillis).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final remainingMillis = _remainingMillis;
    final remainingSeconds = (remainingMillis / 1000).ceil();
    if (remainingMillis == 0 && !_expiredFired) {
      _expiredFired = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onExpired?.call(),
      );
    }
    if (remainingSeconds > 0 &&
        remainingSeconds <= 3 &&
        remainingSeconds != _lastTickedSecond) {
      _lastTickedSecond = remainingSeconds;
      SoundService.instance.play(GameSound.tick);
    }
    final urgent = remainingSeconds <= 5;
    final color = urgent ? AppColors.danger : AppColors.primary;
    final progress = widget.durationSeconds == 0
        ? 0.0
        : remainingMillis / (widget.durationSeconds * 1000);

    return SizedBox(
      width: 84,
      height: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                color: color,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Text(
              '$remainingSeconds',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
