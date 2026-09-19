import 'package:flutter_test/flutter_test.dart';
import 'package:leximera/core/normalize.dart';
import 'package:leximera/data/word_dict.dart';
import 'package:leximera/game/game_state.dart';
import 'package:leximera/ui/share.dart';

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

  test('pack tip unlock: tip1 manual, tip2 @4 fails, tip3 ad/give-up', () {
    GameState base({
      required int currentRow,
      GameStatus status = GameStatus.playing,
      bool manual = false,
      bool ad = false,
      bool gaveUp = false,
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
        adTipUnlocked: ad,
        gaveUp: gaveUp,
        packId: 'mythology',
        packLabel: '⚡ Μυθολογία',
      );
    }

    final zero = base(currentRow: 0);
    expect(zero.isPackTipUnlocked(0), isFalse);
    expect(zero.isPackTipUnlocked(1), isFalse);
    expect(zero.isPackTipUnlocked(2), isFalse);
    expect(zero.canManualRevealTip, isTrue);
    expect(zero.canUnlockAdTip, isTrue);
    expect(zero.canGiveUp, isTrue);

    final tip1 = base(currentRow: 0, manual: true);
    expect(tip1.isPackTipUnlocked(0), isTrue);
    expect(tip1.isPackTipUnlocked(1), isFalse);
    expect(tip1.canManualRevealTip, isFalse);

    final threeFails = base(currentRow: 3);
    expect(threeFails.isPackTipUnlocked(1), isFalse);

    final fourFails = base(currentRow: 4);
    expect(fourFails.isPackTipUnlocked(1), isTrue);
    expect(fourFails.isPackTipUnlocked(2), isFalse);

    final adUnlock = base(currentRow: 1, ad: true);
    expect(adUnlock.isPackTipUnlocked(2), isTrue);
    expect(adUnlock.canUnlockAdTip, isFalse);

    final resigned = base(
      currentRow: 2,
      status: GameStatus.lost,
      gaveUp: true,
      ad: true,
    );
    expect(resigned.isPackTipUnlocked(2), isTrue);
    expect(resigned.canAdvancePack, isTrue);
    expect(resigned.canGiveUp, isFalse);

    // Win does not force-unlock locked tips.
    final won = base(currentRow: 2, status: GameStatus.won, manual: true);
    expect(won.isPackTipUnlocked(0), isTrue);
    expect(won.isPackTipUnlocked(1), isFalse);
    expect(won.isPackTipUnlocked(2), isFalse);
    expect(won.highlightTip3OnWin, isFalse);

    final wonWithTip3 = base(
      currentRow: 2,
      status: GameStatus.won,
      ad: true,
    );
    expect(wonWithTip3.highlightTip3OnWin, isTrue);
  });

  test('share after give-up is X/6 without answer word', () {
    final state = GameState(
      dayIndex: 3,
      answer: 'ΑΘΗΝΑ',
      rows: [
        List.generate(
          5,
          (i) => Tile(letter: 'ΑΒΓΔΕ'[i], state: LetterState.absent),
        ),
        ...List.generate(
          5,
          (_) => List.generate(5, (_) => const Tile()),
        ),
      ],
      currentRow: 1,
      currentGuess: '',
      status: GameStatus.lost,
      streak: 0,
      keyStates: const {},
      packTips: const ['t1', 't2', 't3'],
      gaveUp: true,
      adTipUnlocked: true,
      packId: 'mythology',
      packLabel: '⚡ Μυθολογία',
    );

    final text = buildShareText(state);
    expect(text.contains('X/6'), isTrue);
    expect(text.contains('ΑΘΗΝΑ'), isFalse);
    expect(text.contains('t1'), isFalse);
    // Only the one submitted row of emoji squares.
    final lines = text.split('\n').where((l) => l.contains('⬛') || l.contains('🟩') || l.contains('🟨'));
    expect(lines.length, 1);
  });
}
