/// Answers + guesses + etymology tips for main dict or a thematic pack.
class WordDict {
  WordDict({
    required this.answers,
    required this.guesses,
    required this.etymology,
  });

  final List<String> answers;
  final Set<String> guesses;
  final Map<String, String> etymology;

  bool get isEmpty => answers.isEmpty;

  String answerForDay(int dayIndex) {
    if (answers.isEmpty) {
      throw StateError('Dictionary not loaded');
    }
    var idx = dayIndex % answers.length;
    if (idx < 0) idx += answers.length;
    return answers[idx];
  }

  bool isValidGuess(String matchKey) => guesses.contains(matchKey);

  String? tipFor(String answer) {
    final tip = etymology[answer];
    if (tip == null || tip.trim().isEmpty) return null;
    return tip.trim();
  }
}
