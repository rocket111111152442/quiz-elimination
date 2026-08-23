import 'package:flutter/material.dart';

import '../theme.dart';

enum AnswerButtonState { neutral, selected, correct, wrong }

class AnswerButton extends StatefulWidget {
  final String text;
  final int index;
  final AnswerButtonState state;
  final VoidCallback? onTap;

  const AnswerButton({
    super.key,
    required this.text,
    required this.index,
    required this.state,
    this.onTap,
  });

  @override
  State<AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<AnswerButton> {
  bool _pressed = false;

  Color get _color {
    final baseColor =
        AppColors.answerColors[widget.index % AppColors.answerColors.length];
    switch (widget.state) {
      case AnswerButtonState.correct:
        return AppColors.success;
      case AnswerButtonState.wrong:
        return AppColors.danger;
      case AnswerButtonState.selected:
        return baseColor.withValues(alpha: 0.6);
      case AnswerButtonState.neutral:
        return baseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
