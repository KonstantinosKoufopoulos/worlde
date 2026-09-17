import 'package:flutter_test/flutter_test.dart';
import 'package:leximera/core/normalize.dart';
import 'package:leximera/game/game_state.dart';

void main() {
  test('normalizeGreekWord strips diacritics and uppercases', () {
    expect(normalizeGreekWord('αγάπη'), 'ΑΓΑΠΗ');
    expect(normalizeGreekWord('ΐριδα'), 'ΙΡΙΔΑ');
    expect(normalizeGreekWord('hello'), isNull);
    expect(normalizeGreekWord('ΑΒ'), isNull);
  });

  test('evaluateGuess marks greens then yellows', () {
    final r = evaluateGuess('ΑΒΑΒΑ', 'ΑΑΑΑΑ');
    expect(r[0], LetterState.correct);
    expect(r[1], LetterState.absent);
    expect(r[2], LetterState.correct);
    expect(r[3], LetterState.absent);
    expect(r[4], LetterState.correct);
  });
}
