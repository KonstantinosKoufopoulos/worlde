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
        super(_buildInitial(words, packId: packId, packLabel: packLabel));

  GameController.loading({String? packId})
      : _words = null,
        _packId = packId,
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

  static GameState _buildInitial(
    WordDict words, {
    String? packId,
    String? packLabel,
  }) {
    final day = DictRepository.dayIndex();
    final answer = words.answerForDay(day);
    final tip = words.tipFor(answer);
    final streak = HiveBoxes.streakFor(packId);

    final savedDay =
        HiveBoxes.getScoped(packId, HiveBoxes.keySavedDayIndex) as int?;

    if (savedDay == day) {
      final restored = _restore(
        day,
        answer,
        streak,
        tip,
        packId: packId,
        packLabel: packLabel,
      );
      if (restored != null) return restored;
    } else {
      // New day — clear board persistence for this scope only
      HiveBoxes.deleteScoped(packId, HiveBoxes.keyBoardRows);
      HiveBoxes.deleteScoped(packId, HiveBoxes.keyGameStatus);
      HiveBoxes.putScoped(packId, HiveBoxes.keySavedDayIndex, day);
    }

    return GameState.initial(
      dayIndex: day,
      answer: answer,
      streak: streak,
      etymologyTip: tip,
      packId: packId,
      packLabel: packLabel,
    );
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

    return GameState(
      dayIndex: day,
      answer: answer,
      rows: rows,
      currentRow: guesses.length.clamp(0, GameState.maxRows),
      currentGuess: '',
      status: status,
      streak: streak,
      keyStates: keyStates,
      etymologyTip: tip,
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

  void onKey(String raw) {
    if (_words == null) return;
    if (state.status != GameStatus.playing) return;

    if (raw == 'ENTER') {
      _submit();
      return;
    }
    if (raw == 'BACK') {
      if (state.currentGuess.isEmpty) return;
      final next =
          state.currentGuess.substring(0, state.currentGuess.length - 1);
      state = _withGuess(next).copyWith(clearMessage: true);
      return;
    }

    if (state.currentGuess.length >= GameState.wordLen) return;

    final letter = _singleLetter(raw);
    if (letter == null) return;

    final next = state.currentGuess + letter;
    state = _withGuess(next).copyWith(clearMessage: true);
  }

  String? _singleLetter(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final padded = '$trimmedαααα'.substring(0, 5);
    final one = normalizeGreekWord(padded);
    if (one == null) return null;
    return one[0];
  }

  GameState _withGuess(String guess) {
    final rows = state.rows.map((r) => List<Tile>.from(r)).toList();
    final row = state.currentRow;
    for (var c = 0; c < GameState.wordLen; c++) {
      final ch = c < guess.length ? guess[c] : '';
      rows[row][c] = Tile(
        letter: ch,
        state: ch.isEmpty ? LetterState.empty : LetterState.tbd,
      );
    }
    return state.copyWith(rows: rows, currentGuess: guess);
  }

  void _submit() {
    final words = _words;
    if (words == null) return;
    if (state.currentGuess.length != GameState.wordLen) {
      state = state.copyWith(message: 'Χρειάζονται 5 γράμματα');
      return;
    }

    final key = normalizeGreekWord(state.currentGuess) ?? state.currentGuess;
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

    state = state.copyWith(
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
