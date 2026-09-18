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
  final String? etymologyTip;

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
