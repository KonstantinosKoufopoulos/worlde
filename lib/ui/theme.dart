import 'package:flutter/material.dart';

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
