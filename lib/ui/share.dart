import 'package:flutter/services.dart';

import '../game/game_state.dart';

String buildShareText(GameState state) {
  final n = state.dayIndex + 1; // human-friendly puzzle number
  final score = state.status == GameStatus.won
      ? '${state.guessesUsed}/6'
      : 'X/6';

  final buf = StringBuffer();
  if (state.isPack && state.packLabel != null) {
    buf.writeln('Λεξήμερα · ${state.packLabel} #$n $score');
  } else {
    buf.writeln('Λεξήμερα #$n $score');
  }
  buf.writeln();

  // Win / give-up: only submitted rows. Full loss: all 6 rows.
  // Never includes the answer word or tip text.
  final submitted = state.status == GameStatus.won
      ? state.currentRow
      : (state.gaveUp
          ? state.currentRow
          : (state.status == GameStatus.lost
              ? GameState.maxRows
              : state.currentRow));

  for (var r = 0; r < submitted; r++) {
    final row = state.rows[r];
    for (final tile in row) {
      buf.write(_emoji(tile.state));
    }
    buf.writeln();
  }

  return buf.toString().trimRight();
}

String _emoji(LetterState s) {
  switch (s) {
    case LetterState.correct:
      return '🟩';
    case LetterState.present:
      return '🟨';
    case LetterState.absent:
      return '⬛';
    default:
      return '⬜';
  }
}

Future<void> copyShareText(GameState state) async {
  await Clipboard.setData(ClipboardData(text: buildShareText(state)));
}
