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
    this.packTips = const [],
    this.manualTipUsed = false,
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

  /// Main daily: single tip shown after win. Packs prefer [packTips].
  final String? etymologyTip;

  /// Pack progressive tips (vague → specific), length 0–3.
  final List<String> packTips;

  /// One free manual «Υπόδειξη» used for this pack day.
  final bool manualTipUsed;

  /// Null/empty = main daily. Otherwise thematic pack id.
  final String? packId;
  final String? packLabel;

  bool get isPack => packId != null && packId!.isNotEmpty;

  static const maxRows = 6;
  static const wordLen = 5;

  factory GameState.initial({
    required int dayIndex,
    required String answer,
    required int streak,
    String? etymologyTip,
    List<String> packTips = const [],
    bool manualTipUsed = false,
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
      packTips: packTips,
      manualTipUsed: manualTipUsed,
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
    List<String>? packTips,
    bool? manualTipUsed,
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
      packTips: packTips ?? this.packTips,
      manualTipUsed: manualTipUsed ?? this.manualTipUsed,
      packId: packId ?? this.packId,
      packLabel: packLabel ?? this.packLabel,
    );
  }

  bool get isFinished =>
      status == GameStatus.won || status == GameStatus.lost;

  /// Number of submitted guesses (1–6). After a win, [currentRow] has already advanced.
  int get guessesUsed {
    if (status == GameStatus.won) return currentRow;
    if (status == GameStatus.lost) return maxRows;
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

  /// Auto unlock from wrong guesses: tip1@1, tip2@3, tip3@5.
  int get autoRevealedTipCount {
    final f = failedGuesses;
    if (f >= 5) return 3;
    if (f >= 3) return 2;
    if (f >= 1) return 1;
    return 0;
  }

  /// Whether pack tip at [index] (0-based) is unlocked.
  /// tip1 after 1st fail, tip2 after 3rd, tip3 after 5th OR manual «Υπόδειξη».
  /// On win every tip is unlocked.
  bool isPackTipUnlocked(int index) {
    if (!isPack || index < 0 || index >= packTips.length) return false;
    if (status == GameStatus.won) return true;
    final f = failedGuesses;
    if (index == 0) return f >= 1;
    if (index == 1) return f >= 3;
    if (index == 2) return f >= 5 || manualTipUsed;
    // Extra tips beyond 3 (if any): require same as tip3 auto threshold.
    return f >= 5 || manualTipUsed;
  }

  /// Count of unlocked pack tips (for dots).
  int get revealedTipCount {
    if (!isPack || packTips.isEmpty) return 0;
    var n = 0;
    for (var i = 0; i < packTips.length; i++) {
      if (isPackTipUnlocked(i)) n++;
    }
    return n;
  }

  /// One free manual reveal per pack day — unlocks tip3 early (not tip1/2).
  bool get canManualRevealTip {
    if (!isPack || status != GameStatus.playing) return false;
    if (manualTipUsed) return false;
    if (packTips.length < 3) return false;
    // Already unlocked via 5th fail.
    if (failedGuesses >= 5) return false;
    return true;
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
