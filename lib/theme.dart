import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF5B2AE0);
  static const background = Color(0xFF12081F);
  static const surface = Color(0xFF1E1033);
  static const danger = Color(0xFFE0355B);
  static const success = Color(0xFF2AE07A);

  static const answerColors = [
    Color(0xFFE0355B), // rouge
    Color(0xFF2A7FE0), // bleu
    Color(0xFFE0A22A), // orange
    Color(0xFF2AE0A2), // vert
  ];
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
