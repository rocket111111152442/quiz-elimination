import 'package:flutter/material.dart';

import '../data/uno_cards.dart';
import '../theme.dart';

/// A single UNO card, or the face-down deck back when [card] is null.
class UnoCardWidget extends StatelessWidget {
  final UnoCard? card;
  final bool small;
  final bool disabled;
  final VoidCallback? onTap;

  const UnoCardWidget({
    super.key,
    this.card,
    this.small = false,
    this.disabled = false,
    this.onTap,
  });

  Color get _bgColor {
    if (card == null) return AppColors.surface;
    switch (card!.color) {
      case UnoColor.red:
        return const Color(0xFFD32F2F);
      case UnoColor.yellow:
        return const Color(0xFFF9A825);
      case UnoColor.green:
        return const Color(0xFF2E7D32);
      case UnoColor.blue:
        return const Color(0xFF1565C0);
      case UnoColor.wild:
        return const Color(0xFF1B1B2A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = small ? 46.0 : 64.0;
    final height = small ? 66.0 : 92.0;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
            gradient: card == null
                ? const LinearGradient(
                    colors: [Color(0xFF2A1B3D), Color(0xFF12081F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: card == null
              ? const Text(
                  'UNO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                )
              : Text(
                  card!.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: small ? 16 : 22,
                  ),
                ),
        ),
      ),
    );
  }
}
