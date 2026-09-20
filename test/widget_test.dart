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

  test('share after give-up is X/6 without answer word or tip spoilers', () {
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
      gaveUp: true,
      packId: 'mythology',
      packLabel: '⚡ Μυθολογία',
    );

    final text = buildShareText(state);
    expect(text.contains('X/6'), isTrue);
    expect(text.contains('ΑΘΗΝΑ'), isFalse);
    expect(text.toLowerCase().contains('tip'), isFalse);
    expect(text.contains('Υπόδειξη'), isFalse);
    // Only the one submitted row of emoji squares.
    final lines = text
        .split('\n')
        .where((l) => l.contains('⬛') || l.contains('🟩') || l.contains('🟨'));
    expect(lines.length, 1);
  });

  test('pack resign: canAdvancePack after give-up', () {
    final resigned = GameState(
      dayIndex: 0,
      answer: 'ΑΘΗΝΑ',
      rows: List.generate(
        6,
        (_) => List.generate(5, (_) => const Tile()),
      ),
      currentRow: 2,
      currentGuess: '',
      status: GameStatus.lost,
      streak: 0,
      keyStates: const {},
      gaveUp: true,
      packId: 'mythology',
      packLabel: '⚡ Μυθολογία',
    );
    expect(resigned.canAdvancePack, isTrue);
    expect(resigned.canGiveUp, isFalse);
    expect(resigned.canGrantRewardedLetter, isFalse);
  });

  test('pack rewarded letter: up to 3×, slots, never on main', () {
    GameState pack({
      required List<List<Tile>> rows,
      int currentRow = 0,
      GameStatus status = GameStatus.playing,
      List<int> rewardedCols = const [],
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
        rewardedLetterCols: rewardedCols,
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
    expect(fresh.rewardedLetterCount, 0);
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

    final afterOne = pack(
      rows: rows,
      currentRow: 1,
      rewardedCols: [2],
    );
    expect(afterOne.greenLockedCols, {0, 2});
    expect(afterOne.knownGreenLetter(2), 'Η');
    expect(afterOne.rewardedLetterCount, 1);
    expect(afterOne.canGrantRewardedLetter, isTrue);
    expect(afterOne.emptyLetterSlots, [1, 3, 4]);

    final afterTwo = pack(
      rows: rows,
      currentRow: 1,
      rewardedCols: [2, 4],
    );
    expect(afterTwo.rewardedLetterCount, 2);
    expect(afterTwo.canGrantRewardedLetter, isTrue);

    final afterThree = pack(
      rows: rows,
      currentRow: 1,
      rewardedCols: [2, 4, 1],
    );
    expect(afterThree.rewardedLetterCount, 3);
    expect(afterThree.canGrantRewardedLetter, isFalse);
    expect(afterThree.emptyLetterSlots, [3]);

    // Last empty still grantable when under 3/3 (never auto-solves by itself).
    final lastEmpty = pack(
      rows: rows,
      currentRow: 1,
      rewardedCols: [1, 2, 3],
    );
    // col 0 locked by guess; 1,2,3 rewarded → only col 4 empty, but already 3/3
    expect(lastEmpty.emptyLetterSlots, [4]);
    expect(lastEmpty.canGrantRewardedLetter, isFalse);

    final oneLeftUnderCap = pack(
      rows: rows,
      currentRow: 1,
      rewardedCols: [2, 3],
    );
    expect(oneLeftUnderCap.emptyLetterSlots, [1, 4]);
    expect(oneLeftUnderCap.canGrantRewardedLetter, isTrue);

    final won = pack(rows: emptyRows, status: GameStatus.won);
    expect(won.canGrantRewardedLetter, isFalse);

    final resigned = pack(
      rows: emptyRows,
      status: GameStatus.lost,
      gaveUp: true,
    );
    expect(resigned.canGrantRewardedLetter, isFalse);

    // Zero empty slots → disabled even under 3/3.
    final allGreenRows = List.generate(
      6,
      (_) => List.generate(5, (_) => const Tile()),
    );
    allGreenRows[0] = [
      for (var i = 0; i < 5; i++)
        Tile(letter: 'ΑΘΗΝΑ'[i], state: LetterState.correct),
    ];
    final noSlots = pack(rows: allGreenRows, currentRow: 1, rewardedCols: []);
    expect(noSlots.emptyLetterSlots, isEmpty);
    expect(noSlots.canGrantRewardedLetter, isFalse);

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
