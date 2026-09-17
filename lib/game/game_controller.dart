import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/normalize.dart';
import '../data/dict_repository.dart';
import '../data/hive_boxes.dart';
import 'game_state.dart';

final dictProvider = FutureProvider<DictRepository>((ref) async {
  final repo = DictRepository.instance;
  if (!repo.isLoaded) await repo.load();
  return repo;
});

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((ref) {
  final dict = ref.watch(dictProvider).valueOrNull;
  if (dict == null) {
    return GameController.loading();
  }
  return GameController(dict);
});

class GameController extends StateNotifier<GameState> {
  GameController(DictRepository dict)
      : _dict = dict,
        super(_buildInitial(dict));

  GameController.loading()
      : _dict = null,
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
          ),
        );

  final DictRepository? _dict;

  static GameState _buildInitial(DictRepository dict) {
    final day = DictRepository.dayIndex();
    final answer = dict.answerForDay(day);
    final tip = dict.tipFor(answer);

    // Restore in-progress / finished board for today
    final savedDay = HiveBoxes.settings.get(HiveBoxes.keySavedDayIndex) as int?;
    final streak = HiveBoxes.streak;

    if (savedDay == day) {
      final restored = _restore(dict, day, answer, streak, tip);
      if (restored != null) return restored;
    } else {
      // New day — clear board persistence
      HiveBoxes.settings.delete(HiveBoxes.keyBoardRows);
      HiveBoxes.settings.delete(HiveBoxes.keyGameStatus);
      HiveBoxes.settings.put(HiveBoxes.keySavedDayIndex, day);
    }

    return GameState.initial(
      dayIndex: day,
      answer: answer,
      streak: streak,
      etymologyTip: tip,
    );
  }

  static GameState? _restore(
    DictRepository dict,
    int day,
    String answer,
    int streak,
    String? tip,
  ) {
    final raw = HiveBoxes.settings.get(HiveBoxes.keyBoardRows);
    if (raw is! List) return null;
    final guesses = raw.cast<dynamic>().map((e) => e.toString()).toList();

    var statusName =
        HiveBoxes.settings.get(HiveBoxes.keyGameStatus, defaultValue: 'playing')
            as String;
    var status = GameStatus.values.firstWhere(
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
    if (_dict == null) return;
    if (state.status != GameStatus.playing) return;

    if (raw == 'ENTER') {
      _submit();
      return;
    }
    if (raw == 'BACK') {
      if (state.currentGuess.isEmpty) return;
      final next = state.currentGuess.substring(0, state.currentGuess.length - 1);
      state = _withGuess(next).copyWith(clearMessage: true);
      return;
    }

    if (state.currentGuess.length >= GameState.wordLen) return;

    // Single letter: normalize by padding — better path:
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
    final dict = _dict;
    if (dict == null) return;
    if (state.currentGuess.length != GameState.wordLen) {
      state = state.copyWith(message: 'Χρειάζονται 5 γράμματα');
      return;
    }

    final key = normalizeGreekWord(state.currentGuess) ?? state.currentGuess;
    if (!dict.isValidGuess(key)) {
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

    HiveBoxes.settings.put(HiveBoxes.keyBoardRows, submitted);
    HiveBoxes.settings.put(HiveBoxes.keyGameStatus, status.name);
    HiveBoxes.settings.put(HiveBoxes.keySavedDayIndex, state.dayIndex);

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
    final raw = HiveBoxes.settings.get(HiveBoxes.keyBoardRows);
    if (raw is List) return raw.cast<dynamic>().map((e) => e.toString()).toList();
    return [];
  }

  int _updateStreakOnWin() {
    final day = state.dayIndex;
    final last = HiveBoxes.lastPlayedDay;
    int next;
    if (last == null) {
      next = 1;
    } else if (last == day) {
      // Already counted today
      next = HiveBoxes.streak;
    } else if (last == day - 1) {
      next = HiveBoxes.streak + 1;
    } else {
      next = 1;
    }
    HiveBoxes.streak = next;
    HiveBoxes.lastPlayedDay = day;
    return next;
  }

  void _updateStreakOnLoss() {
    HiveBoxes.streak = 0;
    HiveBoxes.lastPlayedDay = state.dayIndex;
  }
}
