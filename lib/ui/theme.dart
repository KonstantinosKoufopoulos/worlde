import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_boxes.dart';
import '../game/game_state.dart';

class LexColors {
  static const correct = Color(0xFF6AAA64);
  static const present = Color(0xFFC9B458);
  static const absent = Color(0xFF787C7E);
  static const tileBorder = Color(0xFFD3D6DA);
  static const tileBorderDark = Color(0xFF3A3A3C);
}

Color colorForLetterState(LetterState state, Brightness brightness) {
  switch (state) {
    case LetterState.correct:
      return LexColors.correct;
    case LetterState.present:
      return LexColors.present;
    case LetterState.absent:
      return LexColors.absent;
    case LetterState.tbd:
    case LetterState.empty:
      return Colors.transparent;
  }
}

ThemeData buildLightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D5B),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: base.surface,
      foregroundColor: base.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4CAF7A),
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: base.surface,
      foregroundColor: base.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
  );
}

ThemeMode themeModeFromHive(String raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String themeModeToHive(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(themeModeFromHive(HiveBoxes.themeMode));

  void setMode(ThemeMode mode) {
    state = mode;
    HiveBoxes.themeMode = themeModeToHive(mode);
  }

  /// Cycles system → light → dark → system.
  void cycle() {
    switch (state) {
      case ThemeMode.system:
        setMode(ThemeMode.light);
      case ThemeMode.light:
        setMode(ThemeMode.dark);
      case ThemeMode.dark:
        setMode(ThemeMode.system);
    }
  }

  /// Toggles between light and dark (system resolves to opposite of [brightness]).
  void toggleLightDark([Brightness? platformBrightness]) {
    final effective = state == ThemeMode.system
        ? (platformBrightness ?? Brightness.light)
        : (state == ThemeMode.dark ? Brightness.dark : Brightness.light);
    setMode(effective == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

IconData iconForThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Icons.light_mode_outlined;
    case ThemeMode.dark:
      return Icons.dark_mode_outlined;
    case ThemeMode.system:
      return Icons.brightness_auto_outlined;
  }
}

String tooltipForThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Θέμα: φωτεινό';
    case ThemeMode.dark:
      return 'Θέμα: σκοτεινό';
    case ThemeMode.system:
      return 'Θέμα: σύστημα';
  }
}
