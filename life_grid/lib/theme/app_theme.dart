import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which theme mode is active and notifies listeners so the whole
/// app (and the AppColors getters below) can react live when the user
/// toggles it in Settings.
class ThemeController extends ValueNotifier<bool> {
  // value: true = dark, false = light
  ThemeController() : super(true);

  static const _key = 'life_grid_theme_is_dark';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_key) ?? true;
  }

  Future<void> setDark(bool isDark) async {
    value = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}

final themeController = ThemeController();

/// Color palette lifted from the "Grid Assistant" reference, with a
/// light-mode counterpart the user asked for. All fields are getters
/// (not const) so they can switch live based on [themeController].
class AppColors {
  static bool get _dark => themeController.value;

  static Color get bg => _dark ? const Color(0xFF050607) : const Color(0xFFF5F7F7);
  static Color get bgElevated => _dark ? const Color(0xFF0C0F10) : const Color(0xFFFFFFFF);
  static Color get bgCard => _dark ? const Color(0xFF0C0F10) : const Color(0xFFFFFFFF);
  static Color get border => _dark ? const Color(0xFF1C2224) : const Color(0xFFD7DEDE);
  static Color get text => _dark ? const Color(0xFFD8E0E0) : const Color(0xFF10201C);
  static Color get textDim => _dark ? const Color(0xFF6B7878) : const Color(0xFF6E7D7D);

  // Accent/danger/warn are the same in both modes — they're the
  // signal colors and stay recognizable either way.
  static const accent = Color(0xFF39D98A);
  static Color get accentSoft => accent.withOpacity(_dark ? 0.12 : 0.14);
  static const danger = Color(0xFFFF5D5D);
  static const warn = Color(0xFFF0B429);

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

  static ThemeData themeFor(bool isDark) {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final bg = isDark ? const Color(0xFF050607) : const Color(0xFFF5F7F7);
    final bgElevated = isDark ? const Color(0xFF0C0F10) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF1C2224) : const Color(0xFFD7DEDE);
    final text = isDark ? const Color(0xFFD8E0E0) : const Color(0xFF10201C);
    const accent = Color(0xFF39D98A);
    const danger = Color(0xFFFF5D5D);
    final accentSoft = accent.withOpacity(isDark ? 0.12 : 0.14);
    final textDim = isDark ? const Color(0xFF6B7878) : const Color(0xFF6E7D7D);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        surface: bgElevated,
        primary: accent,
        error: danger,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'monospace',
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgElevated,
        elevation: 0,
        foregroundColor: text,
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border),
        ),
      ),
      dividerColor: border,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentSoft,
          foregroundColor: accent,
          side: const BorderSide(color: accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDim,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgElevated,
        selectedItemColor: accent,
        unselectedItemColor: textDim,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData get dark => themeFor(true);
  static ThemeData get light => themeFor(false);
}
