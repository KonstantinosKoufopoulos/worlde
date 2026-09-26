import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/normalize.dart';
import '../data/dict_repository.dart';
import '../data/hive_boxes.dart';
import '../data/pack_meta.dart';
import '../data/word_dict.dart';
import 'game_state.dart';

final dictProvider = FutureProvider<DictRepository>((ref) async {
  final repo = DictRepository.instance;
  if (!repo.isLoaded) await repo.load();
  return repo;
});

final packsCatalogProvider = FutureProvider<List<PackMeta>>((ref) async {
  final repo = await ref.watch(dictProvider.future);
  return repo.loadCatalog();
});

/// Loads main (`''`) or pack word list + optional pack label.
final wordDictProvider =
    FutureProvider.family<({WordDict words, String? packLabel}), String>(
        (ref, packId) async {
  final repo = await ref.watch(dictProvider.future);
  if (packId.isEmpty) {
    return (words: repo.main, packLabel: null);
  }
  final words = await repo.loadPack(packId);
  final meta = await repo.loadPackMeta(packId);
  return (words: words, packLabel: meta.label);
});

/// Family key: empty string = main daily; otherwise pack id.
final gameControllerProvider =
    StateNotifierProvider.family<GameController, GameState, String>(
        (ref, packId) {
  final loaded = ref.watch(wordDictProvider(packId)).valueOrNull;
  if (loaded == null) {
    return GameController.loading(packId: packId.isEmpty ? null : packId);
  }
  return GameController(
    loaded.words,
    packId: packId.isEmpty ? null : packId,
    packLabel: loaded.packLabel,
  );
});

class GameController extends StateNotifier<GameState> {
  GameController(
    WordDict words, {
    String? packId,
    String? packLabel,
  })  : _words = words,
        _packId = packId,
        _packLabel = packLabel,
        super(_buildInitial(words, packId: packId, packLabel: packLabel));

  GameController.loading({String? packId})
      : _words = null,
        _packId = packId,
        _packLabel = null,
        super(
          GameState(
            dayIndex: 0,
            answer: '',
            rows: List.generate(
              GameState.maxRows,
              (_) => List.generate(GameState.wordLen, (_) => const Tile()),
            ),
            currentRow: 0,
            currentGuess: '',
            status: GameStatus.loading,
            streak: 0,
            keyStates: const {},
            packId: packId,
          ),
        );

  final WordDict? _words;
  final String? _packId;
  final String? _packLabel;

  /// Main = UTC calendar day. Packs keep a cursor that can run ahead via
  /// «Επόμενη» after give-up, and catch up when the calendar advances.
  static int _resolveDay({String? packId}) {
    final calendar = DictRepository.dayIndex();
    if (packId == null || packId.isEmpty) return calendar;
    final saved =
        HiveBoxes.getScoped(packId, HiveBoxes.keySavedDayIndex) as int?;
    if (saved != null && saved >= calendar) return saved;
    return calendar;
  }

  static GameState _buildInitial(
    WordDict words, {
    String? packId,
    String? packLabel,
  }) {
    final day = _resolveDay(packId: packId);
    final answer = words.answerForDay(day);
    final isPack = packId != null && packId.isNotEmpty;
    // Main daily keeps single tip for post-win TipCard. Packs: no tip stack.
    final singleTip = isPack ? null : words.tipFor(answer);
    final streak = HiveBoxes.streakFor(packId);

    final savedDay =
        HiveBoxes.getScoped(packId, HiveBoxes.keySavedDayIndex) as int?;

    if (savedDay == day) {
      final restored = _restore(
        day,
        answer,
        streak,
        singleTip,
        packId: packId,
        packLabel: packLabel,
      );
      if (restored != null) return restored;
    } else {
      // New puzzle index — clear board / assist flags for this scope only
      _clearPuzzlePersistence(packId);
      HiveBoxes.putScoped(packId, HiveBoxes.keySavedDayIndex, day);
    }

    return GameState.initial(
      dayIndex: day,
      answer: answer,
      streak: streak,
      etymologyTip: singleTip,
      packId: packId,
      packLabel: packLabel,
    );
  }

  static void _clearPuzzlePersistence(String? packId) {
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyBoardRows);
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyGameStatus);
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyGaveUp);
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyRewardedLetterCols);
    // Legacy tip / 1× letter keys
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyManualTipReveal);
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyAdTipUnlock);
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyRewardedLetterUsed);
    HiveBoxes.deleteScoped(packId, HiveBoxes.keyRewardedLetterCol);
  }

  static List<int> _loadRewardedCols(String? packId) {
    final raw = HiveBoxes.getScoped(packId, HiveBoxes.keyRewardedLetterCols);
    if (raw is List) {
      final cols = <int>[];
      for (final e in raw) {
        if (e is int && e >= 0 && e < GameState.wordLen && !cols.contains(e)) {
          cols.add(e);
        }
      }
      if (cols.length > GameState.maxRewardedLetters) {
        return cols.sublist(0, GameState.maxRewardedLetters);
      }
      return cols;
    }
    // Migrate legacy single-column grant.
    final legacy =
        HiveBoxes.getScoped(packId, HiveBoxes.keyRewardedLetterCol);
    if (legacy is int && legacy >= 0 && legacy < GameState.wordLen) {
      return [legacy];
    }
    return const [];
  }

  static GameState? _restore(
    int day,
    String answer,
    int streak,
    String? tip, {
    String? packId,
    String? packLabel,
  }) {
    final raw = HiveBoxes.getScoped(packId, HiveBoxes.keyBoardRows);
    if (raw is! List) return null;
    final guesses = raw.cast<dynamic>().map((e) => e.toString()).toList();

    final statusName = HiveBoxes.getScoped(
          packId,
          HiveBoxes.keyGameStatus,
        ) as String? ??
        'playing';
    final status = GameStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => GameStatus.playing,
    );

    final gaveUp = HiveBoxes.getScoped(packId, HiveBoxes.keyGaveUp) == true;
    final rewardedLetterCols = _loadRewardedCols(packId);

    final rows = List.generate(
      GameState.maxRows,
      (_) => List.generate(GameState.wordLen, (_) => const Tile()),
    );
    final keyStates = <String, LetterState>{};

    for (var r = 0; r < guesses.length && r < GameState.maxRows; r++) {
      final g = guesses[r];
      if (g.length != 5) continue;
      final eval = evaluateGuess(g, answer);
      for (var c = 0; c < 5; c++) {
        rows[r][c] = Tile(letter: g[c], state: eval[c]);
        _mergeKey(keyStates, g[c], eval[c]);
      }
    }

    final currentRow = guesses.length.clamp(0, GameState.maxRows);
    // Re-apply rewarded letters onto the in-progress row (does not use a guess).
    if (status == GameStatus.playing &&
        currentRow < GameState.maxRows &&
        answer.length == GameState.wordLen) {
      for (final c in rewardedLetterCols) {
        if (c < 0 || c >= GameState.wordLen) continue;
        final ch = answer[c];
        rows[currentRow][c] = Tile(letter: ch, state: LetterState.correct);
        _mergeKey(keyStates, ch, LetterState.correct);
      }
    }

    return GameState(
      dayIndex: day,
      answer: answer,
      rows: rows,
      currentRow: currentRow,
      currentGuess: '',
      status: status,
      streak: streak,
      keyStates: keyStates,
      etymologyTip: tip,
      gaveUp: gaveUp,
      rewardedLetterCols: rewardedLetterCols,
      packId: packId,
      packLabel: packLabel,
    );
  }

  static void _mergeKey(
    Map<String, LetterState> map,
    String letter,
    LetterState next,
  ) {
    final prev = map[letter];
    if (prev == LetterState.correct) return;
    if (next == LetterState.correct) {
      map[letter] = LetterState.correct;
      return;
    }
    if (prev == LetterState.present) return;
    if (next == LetterState.present) {
      map[letter] = LetterState.present;
      return;
    }
    map[letter] = LetterState.absent;
  }

  void clearMessage() {
    if (state.message != null) {
      state = state.copyWith(clearMessage: true);
    }
  }

  /// Pack rewarded letter. Call only after the rewarded ad reports the reward
  /// (Android: AdMob onUserEarnedReward; web/desktop stub: instantly).
  /// Fills one random non-green column with the correct letter on the current
  /// row (green). Does not consume a guess row and never auto-wins — even when
  /// filling the last empty slot.
  void grantRewardedLetter() {
    if (!state.canGrantRewardedLetter) return;
    final slots = state.emptyLetterSlots;
    if (slots.isEmpty) return;

    final col = slots[Random().nextInt(slots.length)];
    final letter = state.answer[col];

    final nextCols = [...state.rewardedLetterCols, col];
    HiveBoxes.putScoped(_packId, HiveBoxes.keyRewardedLetterCols, nextCols);

    // Drop any typed letter that occupied this column in the composed row.
    final typed = _typedGuessFromState(state);
    final rebuilt = _rebuildTypedAfterLock(typed, state.rewardedLockCols, col);

    final keyStates = Map<String, LetterState>.from(state.keyStates);
    _mergeKey(keyStates, letter, LetterState.correct);

    var next = state.copyWith(
      rewardedLetterCols: nextCols,
      currentGuess: rebuilt,
      keyStates: keyStates,
      clearMessage: true,
    );
    // Paint only — never change status to won here.
    next = _paintCurrentRow(next, rebuilt);
    assert(next.status == GameStatus.playing);
    state = next;
  }

  /// Pack give-up: reveal answer, mark lost + gaveUp.
  void giveUp() {
    if (!state.canGiveUp) return;
    _updateStreakOnLoss();
    HiveBoxes.putScoped(_packId, HiveBoxes.keyGameStatus, GameStatus.lost.name);
    HiveBoxes.putScoped(_packId, HiveBoxes.keyGaveUp, true);
    HiveBoxes.putScoped(_packId, HiveBoxes.keySavedDayIndex, state.dayIndex);
    state = state.copyWith(
      status: GameStatus.lost,
      gaveUp: true,
      streak: 0,
      currentGuess: '',
      message: 'Η λέξη ήταν ${state.answer}',
    );
  }

  /// After give-up «Επόμενη»: advance this pack's day/index and load next puzzle.
  void advancePackPuzzle() {
    if (!state.canAdvancePack) return;
    final words = _words;
    if (words == null) return;

    final nextDay = state.dayIndex + 1;
    _clearPuzzlePersistence(_packId);
    HiveBoxes.putScoped(_packId, HiveBoxes.keySavedDayIndex, nextDay);

    final answer = words.answerForDay(nextDay);
    final streak = HiveBoxes.streakFor(_packId);

    state = GameState.initial(
      dayIndex: nextDay,
      answer: answer,
      streak: streak,
      packId: _packId,
      packLabel: _packLabel ?? state.packLabel,
    );
  }

  void onKey(String raw) {
    if (_words == null) return;
    if (state.status != GameStatus.playing) return;

    if (raw == 'ENTER') {
      _submit();
      return;
    }
    if (raw == 'BACK') {
      final typed = _typedGuessFromState(state);
      if (typed.isEmpty) return;
      final next = typed.substring(0, typed.length - 1);
      state = _paintCurrentRow(state, next).copyWith(clearMessage: true);
      return;
    }

    final locked = state.rewardedLockCols;
    final typed = _typedGuessFromState(state);
    final capacity = GameState.wordLen - locked.length;
    if (typed.length >= capacity) return;

    final letter = _singleLetter(raw);
    if (letter == null) return;

    final next = typed + letter;
    state = _paintCurrentRow(state, next).copyWith(clearMessage: true);
  }

  String? _singleLetter(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final padded = '$trimmedαααα'.substring(0, 5);
    final one = normalizeGreekWord(padded);
    if (one == null) return null;
    return one[0];
  }

  /// User-typed letters for non-locked columns (left-to-right).
  static String _typedGuessFromState(GameState s) => s.currentGuess;

  static String _rebuildTypedAfterLock(
    String typed,
    Set<int> previouslyLocked,
    int newLockCol,
  ) {
    // Reconstruct composed row from old locks + typed, then drop newLockCol.
    final chars = List<String>.filled(GameState.wordLen, '');
    for (final c in previouslyLocked) {
      chars[c] = '·';
    }
    var ti = 0;
    for (var c = 0; c < GameState.wordLen; c++) {
      if (chars[c].isNotEmpty) continue;
      if (ti < typed.length) {
        chars[c] = typed[ti++];
      }
    }
    chars[newLockCol] = '·';
    final buf = StringBuffer();
    for (var c = 0; c < GameState.wordLen; c++) {
      if (chars[c].isEmpty || chars[c] == '·') continue;
      buf.write(chars[c]);
    }
    return buf.toString();
  }

  /// Compose full 5-letter row from rewarded locks + typed letters.
  static String? _composeGuess(GameState s, String typed) {
    if (s.answer.length != GameState.wordLen) return null;
    final locked = s.rewardedLockCols;
    final chars = List<String>.filled(GameState.wordLen, '');
    for (final c in locked) {
      chars[c] = s.answer[c];
    }
    var ti = 0;
    for (var c = 0; c < GameState.wordLen; c++) {
      if (chars[c].isNotEmpty) continue;
      if (ti >= typed.length) return null; // incomplete
      chars[c] = typed[ti++];
    }
    if (ti != typed.length) return null;
    return chars.join();
  }

  /// Paint current row: rewarded cols = green correct; others from [typed].
  GameState _paintCurrentRow(GameState s, String typed) {
    final rows = s.rows.map((r) => List<Tile>.from(r)).toList();
    final row = s.currentRow;
    if (row >= GameState.maxRows) {
      return s.copyWith(currentGuess: typed);
    }
    final locked = s.rewardedLockCols;
    final answer = s.answer;
    final chars = List<String>.filled(GameState.wordLen, '');
    for (final c in locked) {
      if (c < answer.length) chars[c] = answer[c];
    }
    var ti = 0;
    for (var c = 0; c < GameState.wordLen; c++) {
      if (chars[c].isNotEmpty) continue;
      if (ti < typed.length) {
        chars[c] = typed[ti++];
      }
    }
    for (var c = 0; c < GameState.wordLen; c++) {
      final ch = chars[c];
      if (locked.contains(c) && ch.isNotEmpty) {
        rows[row][c] = Tile(letter: ch, state: LetterState.correct);
      } else if (ch.isEmpty) {
        rows[row][c] = const Tile();
      } else {
        rows[row][c] = Tile(letter: ch, state: LetterState.tbd);
      }
    }
    return s.copyWith(rows: rows, currentGuess: typed);
  }

  void _submit() {
    final words = _words;
    if (words == null) return;

    final typed = _typedGuessFromState(state);
    final composed = _composeGuess(state, typed);
    if (composed == null || composed.length != GameState.wordLen) {
      state = state.copyWith(message: 'Χρειάζονται 5 γράμματα');
      return;
    }

    final key = normalizeGreekWord(composed) ?? composed;
    if (!words.isValidGuess(key)) {
      state = state.copyWith(message: 'Η λέξη δεν υπάρχει στη λίστα');
      return;
    }

    final eval = evaluateGuess(key, state.answer);
    final rows = state.rows.map((r) => List<Tile>.from(r)).toList();
    final keyStates = Map<String, LetterState>.from(state.keyStates);

    for (var c = 0; c < 5; c++) {
      rows[state.currentRow][c] = Tile(letter: key[c], state: eval[c]);
      _mergeKey(keyStates, key[c], eval[c]);
    }

    final submitted = _persistedGuesses()..add(key);
    final nextRow = state.currentRow + 1;
    final won = key == state.answer;
    final lost = !won && nextRow >= GameState.maxRows;

    var streak = state.streak;
    var status = GameStatus.playing;

    if (won) {
      status = GameStatus.won;
      streak = _updateStreakOnWin();
    } else if (lost) {
      status = GameStatus.lost;
      _updateStreakOnLoss();
      streak = 0;
    }

    HiveBoxes.putScoped(_packId, HiveBoxes.keyBoardRows, submitted);
    HiveBoxes.putScoped(_packId, HiveBoxes.keyGameStatus, status.name);
    HiveBoxes.putScoped(_packId, HiveBoxes.keySavedDayIndex, state.dayIndex);

    var next = state.copyWith(
      rows: rows,
      currentRow: nextRow,
      currentGuess: '',
      status: status,
      streak: streak,
      keyStates: keyStates,
      clearMessage: true,
      message: won
          ? 'Μπράβο!'
          : (lost ? 'Η λέξη ήταν ${state.answer}' : null),
    );

    // Carry green locks onto the next in-progress row (no extra guess used).
    if (status == GameStatus.playing && nextRow < GameState.maxRows) {
      next = _paintCurrentRow(next, '');
    }

    state = next;
  }

  List<String> _persistedGuesses() {
    final raw = HiveBoxes.getScoped(_packId, HiveBoxes.keyBoardRows);
    if (raw is List) {
      return raw.cast<dynamic>().map((e) => e.toString()).toList();
    }
    return [];
  }

  int _updateStreakOnWin() {
    final day = state.dayIndex;
    final last = HiveBoxes.lastPlayedDayFor(_packId);
    final int next;
    if (last == null) {
      next = 1;
    } else if (last == day) {
      next = HiveBoxes.streakFor(_packId);
    } else if (last == day - 1) {
      next = HiveBoxes.streakFor(_packId) + 1;
    } else {
      next = 1;
    }
    HiveBoxes.setStreakFor(_packId, next);
    HiveBoxes.setLastPlayedDayFor(_packId, day);
    return next;
  }

  void _updateStreakOnLoss() {
    HiveBoxes.setStreakFor(_packId, 0);
    HiveBoxes.setLastPlayedDayFor(_packId, state.dayIndex);
  }
}
