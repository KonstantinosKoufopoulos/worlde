enum LetterState { empty, tbd, correct, present, absent }

enum GameStatus { loading, playing, won, lost }

class Tile {
  const Tile({this.letter = '', this.state = LetterState.empty});

  final String letter;
  final LetterState state;

  Tile copyWith({String? letter, LetterState? state}) => Tile(
        letter: letter ?? this.letter,
        state: state ?? this.state,
      );
}

class GameState {
  const GameState({
    required this.dayIndex,
    required this.answer,
    required this.rows,
    required this.currentRow,
    required this.currentGuess,
    required this.status,
    required this.streak,
    required this.keyStates,
    this.message,
    this.etymologyTip,
    this.gaveUp = false,
    this.rewardedLetterCols = const [],
    this.packId,
    this.packLabel,
  });

  final int dayIndex;
  final String answer;
  final List<List<Tile>> rows; // 6 x 5
  final int currentRow;
  final String currentGuess;
  final GameStatus status;
  final int streak;
  final Map<String, LetterState> keyStates;
  final String? message;

  /// Main daily: single tip shown after win. Packs do not use this.
  final String? etymologyTip;

  /// Pack-only: player resigned and revealed the answer.
  final bool gaveUp;

  /// Pack-only: columns filled by rewarded letters (0–3 entries, each 0–4).
  final List<int> rewardedLetterCols;

  /// Null/empty = main daily. Otherwise thematic pack id.
  final String? packId;
  final String? packLabel;

  bool get isPack => packId != null && packId!.isNotEmpty;

  static const maxRows = 6;
  static const wordLen = 5;
  static const maxRewardedLetters = 3;

  factory GameState.initial({
    required int dayIndex,
    required String answer,
    required int streak,
    String? etymologyTip,
    bool gaveUp = false,
    List<int> rewardedLetterCols = const [],
    String? packId,
    String? packLabel,
  }) {
    return GameState(
      dayIndex: dayIndex,
      answer: answer,
      rows: List.generate(
        maxRows,
        (_) => List.generate(wordLen, (_) => const Tile()),
      ),
      currentRow: 0,
      currentGuess: '',
      status: GameStatus.playing,
      streak: streak,
      keyStates: {},
      etymologyTip: etymologyTip,
      gaveUp: gaveUp,
      rewardedLetterCols: rewardedLetterCols,
      packId: packId,
      packLabel: packLabel,
    );
  }

  GameState copyWith({
    int? dayIndex,
    String? answer,
    List<List<Tile>>? rows,
    int? currentRow,
    String? currentGuess,
    GameStatus? status,
    int? streak,
    Map<String, LetterState>? keyStates,
    String? message,
    bool clearMessage = false,
    String? etymologyTip,
    bool? gaveUp,
    List<int>? rewardedLetterCols,
    String? packId,
    String? packLabel,
  }) {
    return GameState(
      dayIndex: dayIndex ?? this.dayIndex,
      answer: answer ?? this.answer,
      rows: rows ?? this.rows,
      currentRow: currentRow ?? this.currentRow,
      currentGuess: currentGuess ?? this.currentGuess,
      status: status ?? this.status,
      streak: streak ?? this.streak,
      keyStates: keyStates ?? this.keyStates,
      message: clearMessage ? null : (message ?? this.message),
      etymologyTip: etymologyTip ?? this.etymologyTip,
      gaveUp: gaveUp ?? this.gaveUp,
      rewardedLetterCols: rewardedLetterCols ?? this.rewardedLetterCols,
      packId: packId ?? this.packId,
      packLabel: packLabel ?? this.packLabel,
    );
  }

  bool get isFinished =>
      status == GameStatus.won || status == GameStatus.lost;

  /// Number of submitted guesses (1–6). After a win, [currentRow] has already advanced.
  int get guessesUsed {
    if (status == GameStatus.won) return currentRow;
    if (status == GameStatus.lost) {
      return gaveUp ? currentRow : maxRows;
    }
    return currentRow;
  }

  bool get wonInGuesses => status == GameStatus.won;

  /// Wrong submitted guesses so far (excludes the winning guess).
  int get failedGuesses {
    if (status == GameStatus.won) {
      final n = currentRow - 1;
      return n < 0 ? 0 : n;
    }
    return currentRow;
  }

  /// Muted give-up CTA while a pack puzzle is in progress.
  bool get canGiveUp {
    if (!isPack || status != GameStatus.playing) return false;
    return true;
  }

  /// After give-up: show «Επόμενη» to advance this pack's puzzle index.
  bool get canAdvancePack => isPack && gaveUp && status == GameStatus.lost;

  int get rewardedLetterCount => rewardedLetterCols.length;

  /// Columns forced onto the current row by rewarded letters.
  Set<int> get rewardedLockCols {
    final cols = <int>{};
    for (final c in rewardedLetterCols) {
      if (c >= 0 && c < wordLen) cols.add(c);
    }
    return cols;
  }

  /// Columns already known green (submitted correct and/or rewarded letters).
  Set<int> get greenLockedCols {
    final cols = <int>{};
    for (var r = 0; r < currentRow && r < rows.length; r++) {
      for (var c = 0; c < wordLen; c++) {
        if (rows[r][c].state == LetterState.correct) cols.add(c);
      }
    }
    cols.addAll(rewardedLockCols);
    return cols;
  }

  /// Answer positions not yet green-locked (candidates for rewarded letter).
  List<int> get emptyLetterSlots {
    final locked = greenLockedCols;
    return [for (var c = 0; c < wordLen; c++) if (!locked.contains(c)) c];
  }

  /// Pack rewarded-letter CTA — up to 3× while playing, needs an empty slot.
  /// Granting the last empty slot never auto-solves (caller must not win).
  bool get canGrantRewardedLetter {
    if (!isPack || status != GameStatus.playing) return false;
    if (gaveUp) return false;
    if (rewardedLetterCount >= maxRewardedLetters) return false;
    return emptyLetterSlots.isNotEmpty;
  }

  /// Known-green letter at [col] for hard-mode constraints / auto-fill.
  String? knownGreenLetter(int col) {
    if (col < 0 || col >= wordLen || answer.length != wordLen) return null;
    if (!greenLockedCols.contains(col)) return null;
    return answer[col];
  }
}

/// Classic evaluation: greens first, then yellows with counts.
List<LetterState> evaluateGuess(String guess, String answer) {
  assert(guess.length == 5 && answer.length == 5);
  final result = List<LetterState>.filled(5, LetterState.absent);
  final remaining = <String, int>{};

  for (var i = 0; i < 5; i++) {
    if (guess[i] == answer[i]) {
      result[i] = LetterState.correct;
    } else {
      remaining[answer[i]] = (remaining[answer[i]] ?? 0) + 1;
    }
  }

  for (var i = 0; i < 5; i++) {
    if (result[i] == LetterState.correct) continue;
    final ch = guess[i];
    final count = remaining[ch] ?? 0;
    if (count > 0) {
      result[i] = LetterState.present;
      remaining[ch] = count - 1;
    } else {
      result[i] = LetterState.absent;
    }
  }
  return result;
}
