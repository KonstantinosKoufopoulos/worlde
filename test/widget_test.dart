import 'package:flutter_test/flutter_test.dart';
import 'package:leximera/core/normalize.dart';
import 'package:leximera/data/word_dict.dart';
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

  test('WordDict.parseTips accepts legacy string and array', () {
    expect(WordDict.parseTips('μία γραμμή'), ['μία γραμμή']);
    expect(WordDict.parseTips(['α', 'β', 'γ']), ['α', 'β', 'γ']);
    expect(WordDict.parseTips(''), isEmpty);
    expect(WordDict.parseTips(null), isEmpty);
  });

  test('pack tip unlock: 1 / 3 / 5 fails + manual tip3', () {
    GameState base({
      required int currentRow,
      GameStatus status = GameStatus.playing,
      bool manual = false,
    }) {
      return GameState(
        dayIndex: 0,
        answer: 'ΑΘΗΝΑ',
        rows: List.generate(
          6,
          (_) => List.generate(5, (_) => const Tile()),
        ),
        currentRow: currentRow,
        currentGuess: '',
        status: status,
        streak: 0,
        keyStates: const {},
        packTips: const ['t1', 't2', 't3'],
        manualTipUsed: manual,
        packId: 'mythology',
        packLabel: '⚡ Μυθολογία',
      );
    }

    final zero = base(currentRow: 0);
    expect(zero.isPackTipUnlocked(0), isFalse);
    expect(zero.isPackTipUnlocked(1), isFalse);
    expect(zero.isPackTipUnlocked(2), isFalse);
    expect(zero.canManualRevealTip, isTrue);

    final one = base(currentRow: 1);
    expect(one.isPackTipUnlocked(0), isTrue);
    expect(one.isPackTipUnlocked(1), isFalse);
    expect(one.isPackTipUnlocked(2), isFalse);

    final three = base(currentRow: 3);
    expect(three.isPackTipUnlocked(0), isTrue);
    expect(three.isPackTipUnlocked(1), isTrue);
    expect(three.isPackTipUnlocked(2), isFalse);

    final five = base(currentRow: 5);
    expect(five.isPackTipUnlocked(2), isTrue);
    expect(five.canManualRevealTip, isFalse);

    final earlyManual = base(currentRow: 1, manual: true);
    expect(earlyManual.isPackTipUnlocked(0), isTrue);
    expect(earlyManual.isPackTipUnlocked(1), isFalse);
    expect(earlyManual.isPackTipUnlocked(2), isTrue);
    expect(earlyManual.canManualRevealTip, isFalse);

    final won = base(currentRow: 2, status: GameStatus.won);
    expect(won.isPackTipUnlocked(0), isTrue);
    expect(won.isPackTipUnlocked(1), isTrue);
    expect(won.isPackTipUnlocked(2), isTrue);
    expect(won.revealedTipCount, 3);
  });
}
