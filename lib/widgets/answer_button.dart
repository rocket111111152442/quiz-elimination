import 'package:flutter/material.dart';

import '../theme.dart';

enum AnswerButtonState { neutral, selected, correct, wrong }

class AnswerButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final baseColor =
        AppColors.answerColors[index % AppColors.answerColors.length];
    Color color;
    switch (state) {
      case AnswerButtonState.correct:
        color = AppColors.success;
        break;
      case AnswerButtonState.wrong:
        color = AppColors.danger;
        break;
      case AnswerButtonState.selected:
        color = baseColor.withValues(alpha: 0.6);
        break;
      case AnswerButtonState.neutral:
        color = baseColor;
        break;
    }

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
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
