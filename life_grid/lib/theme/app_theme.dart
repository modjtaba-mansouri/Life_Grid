import 'package:flutter/material.dart';

/// Palette lifted directly from the "Grid Assistant" reference:
/// near-black terminal background, flat bordered panels, no shadows,
/// small radii, green accent / red danger / amber warn.
class AppColors {
  static const bg = Color(0xFF050607);
  static const bgElevated = Color(0xFF0C0F10);
  static const bgCard = Color(0xFF0C0F10);
  static const border = Color(0xFF1C2224);
  static const text = Color(0xFFD8E0E0);
  static const textDim = Color(0xFF6B7878);
  static const accent = Color(0xFF39D98A);
  static const accentSoft = Color(0x1F39D98A); // ~12% opacity
  static const danger = Color(0xFFFF5D5D);
  static const warn = Color(0xFFF0B429);

  // 5-stage rating scale colors: Disaster -> Wonderful
  static const stageColors = <Color>[
    danger, // 1 Disaster — red
    Color(0xFFE08A3C), // 2 Bad — orange
    Color(0xFFAEB8B8), // 3 Neutral — gray/white
    Color(0xFF7FD98A), // 4 Good — light green
    Color(0xFF1E8F4E), // 5 Wonderful — dark green
  ];

  static const stageLabels = <String>[
    'Disaster',
    'Bad',
    'Neutral',
    'Good',
    'Wonderful',
  ];
}

class AppTheme {
  static const double radius = 4;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.bgElevated,
        primary: AppColors.accent,
        error: AppColors.danger,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'monospace',
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        foregroundColor: AppColors.text,
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerColor: AppColors.border,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDim,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDim,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
