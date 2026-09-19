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

  test('pack rewarded letter: slots, 1× gate, known green', () {
    GameState pack({
      required List<List<Tile>> rows,
      int currentRow = 0,
      GameStatus status = GameStatus.playing,
      bool rewardedUsed = false,
      int? rewardedCol,
      bool gaveUp = false,
    }) {
      return GameState(
        dayIndex: 0,
        answer: 'ΑΘΗΝΑ',
        rows: rows,
        currentRow: currentRow,
        currentGuess: '',
        status: status,
        streak: 0,
        keyStates: const {},
        packTips: const ['t1', 't2', 't3'],
        rewardedLetterUsed: rewardedUsed,
        rewardedLetterCol: rewardedCol,
        gaveUp: gaveUp,
        packId: 'mythology',
        packLabel: '⚡ Μυθολογία',
      );
    }

    final emptyRows = List.generate(
      6,
      (_) => List.generate(5, (_) => const Tile()),
    );
    final fresh = pack(rows: emptyRows);
    expect(fresh.emptyLetterSlots, [0, 1, 2, 3, 4]);
    expect(fresh.canGrantRewardedLetter, isTrue);
    expect(fresh.knownGreenLetter(0), isNull);

    // One submitted green at col 0.
    final rows = List.generate(
      6,
      (_) => List.generate(5, (_) => const Tile()),
    );
    rows[0] = [
      const Tile(letter: 'Α', state: LetterState.correct),
      const Tile(letter: 'Β', state: LetterState.absent),
      const Tile(letter: 'Γ', state: LetterState.absent),
      const Tile(letter: 'Δ', state: LetterState.absent),
      const Tile(letter: 'Ε', state: LetterState.absent),
    ];
    final partial = pack(rows: rows, currentRow: 1);
    expect(partial.greenLockedCols, {0});
    expect(partial.emptyLetterSlots, [1, 2, 3, 4]);
    expect(partial.knownGreenLetter(0), 'Α');
    expect(partial.canGrantRewardedLetter, isTrue);

    final afterReward = pack(
      rows: rows,
      currentRow: 1,
      rewardedUsed: true,
      rewardedCol: 2,
    );
    expect(afterReward.greenLockedCols, {0, 2});
    expect(afterReward.knownGreenLetter(2), 'Η');
    expect(afterReward.canGrantRewardedLetter, isFalse);
    expect(afterReward.emptyLetterSlots, [1, 3, 4]);

    final won = pack(rows: emptyRows, status: GameStatus.won);
    expect(won.canGrantRewardedLetter, isFalse);

    final resigned = pack(
      rows: emptyRows,
      status: GameStatus.lost,
      gaveUp: true,
    );
    expect(resigned.canGrantRewardedLetter, isFalse);

    // Main daily: never.
    final main = GameState(
      dayIndex: 0,
      answer: 'ΑΘΗΝΑ',
      rows: emptyRows,
      currentRow: 0,
      currentGuess: '',
      status: GameStatus.playing,
      streak: 0,
      keyStates: const {},
    );
    expect(main.canGrantRewardedLetter, isFalse);
  });
}
