import 'dart:async';

import 'package:flutter/material.dart';

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
    final elapsed = DateTime.now().difference(widget.startedAt).inSeconds;
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
    final urgent = remaining <= 5;
    return Text(
      '$remaining',
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: urgent ? Colors.redAccent : Colors.white,
      ),
    );
  }
}
