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
    this.adTipUnlocked = false,
    this.gaveUp = false,
    this.rewardedLetterUsed = false,
    this.rewardedLetterCol,
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

  /// Pack tip1: one free «Υπόδειξη» used for this pack puzzle.
  final bool manualTipUsed;

  /// Pack tip3: unlocked via rewarded-ad stub (or give-up).
  final bool adTipUnlocked;

  /// Pack-only: player resigned and revealed the answer.
  final bool gaveUp;

  /// Pack-only: rewarded-letter ad used once for this puzzle.
  final bool rewardedLetterUsed;

  /// Pack-only: column filled by rewarded letter (0–4), if granted.
  final int? rewardedLetterCol;

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
    bool adTipUnlocked = false,
    bool gaveUp = false,
    bool rewardedLetterUsed = false,
    int? rewardedLetterCol,
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
      adTipUnlocked: adTipUnlocked,
      gaveUp: gaveUp,
      rewardedLetterUsed: rewardedLetterUsed,
      rewardedLetterCol: rewardedLetterCol,
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
    bool? adTipUnlocked,
    bool? gaveUp,
    bool? rewardedLetterUsed,
    int? rewardedLetterCol,
    bool clearRewardedLetterCol = false,
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
      adTipUnlocked: adTipUnlocked ?? this.adTipUnlocked,
      gaveUp: gaveUp ?? this.gaveUp,
      rewardedLetterUsed: rewardedLetterUsed ?? this.rewardedLetterUsed,
      rewardedLetterCol: clearRewardedLetterCol
          ? null
          : (rewardedLetterCol ?? this.rewardedLetterCol),
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

  /// Pack tip unlock (Christos):
  /// tip1 = free «Υπόδειξη» once; tip2 = auto after 4 fails; tip3 = ad stub / give-up.
  /// Win does **not** force-unlock remaining tips.
  bool isPackTipUnlocked(int index) {
    if (!isPack || index < 0 || index >= packTips.length) return false;
    if (index == 0) return manualTipUsed;
    if (index == 1) return failedGuesses >= 4;
    if (index == 2) return adTipUnlocked || gaveUp;
    return adTipUnlocked || gaveUp;
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

  /// Free tip1 «Υπόδειξη» — 1× per pack puzzle, anytime while playing.
  bool get canManualRevealTip {
    if (!isPack || status != GameStatus.playing) return false;
    if (manualTipUsed) return false;
    if (packTips.isEmpty) return false;
    return true;
  }

  /// Tip3 rewarded-ad stub CTA — anytime while playing until unlocked.
  bool get canUnlockAdTip {
    if (!isPack || status != GameStatus.playing) return false;
    if (packTips.length < 3) return false;
    if (adTipUnlocked || gaveUp) return false;
    return true;
  }

  /// Muted give-up CTA while a pack puzzle is in progress.
  bool get canGiveUp {
    if (!isPack || status != GameStatus.playing) return false;
    return true;
  }

  /// After give-up: show «Επόμενη» to advance this pack's puzzle index.
  bool get canAdvancePack => isPack && gaveUp && status == GameStatus.lost;

  /// Highlight tip3 on win when it was unlocked (ad / give-up path).
  bool get highlightTip3OnWin =>
      status == GameStatus.won && isPackTipUnlocked(2);

  /// Columns forced onto the current row by the rewarded letter (0–1 cols).
  Set<int> get rewardedLockCols {
    final rewarded = rewardedLetterCol;
    if (rewarded == null || rewarded < 0 || rewarded >= wordLen) return {};
    return {rewarded};
  }

  /// Columns already known green (submitted correct and/or rewarded letter).
  Set<int> get greenLockedCols {
    final cols = <int>{};
    for (var r = 0; r < currentRow && r < rows.length; r++) {
      for (var c = 0; c < wordLen; c++) {
        if (rows[r][c].state == LetterState.correct) cols.add(c);
      }
    }
    final rewarded = rewardedLetterCol;
    if (rewarded != null && rewarded >= 0 && rewarded < wordLen) {
      cols.add(rewarded);
    }
    return cols;
  }

  /// Answer positions not yet green-locked (candidates for rewarded letter).
  List<int> get emptyLetterSlots {
    final locked = greenLockedCols;
    return [for (var c = 0; c < wordLen; c++) if (!locked.contains(c)) c];
  }

  /// Pack rewarded-letter CTA — 1× while playing, needs an empty slot.
  bool get canGrantRewardedLetter {
    if (!isPack || status != GameStatus.playing) return false;
    if (gaveUp || rewardedLetterUsed) return false;
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
