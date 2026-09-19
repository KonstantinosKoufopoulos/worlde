/// Answers + guesses + etymology tips for main dict or a thematic pack.
class WordDict {
  WordDict({
    required this.answers,
    required this.guesses,
    required this.etymology,
  });

  final List<String> answers;
  final Set<String> guesses;

  /// Normalized tips per answer (always a list). Legacy string values become
  /// a single-element list; pack tips are length 2–3 (vague → specific).
  final Map<String, List<String>> etymology;

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

  /// All tips for [answer] (empty if missing).
  List<String> tipsFor(String answer) {
    final tips = etymology[answer];
    if (tips == null || tips.isEmpty) return const [];
    return List<String>.unmodifiable(tips);
  }

  /// Single-line tip (main daily / legacy). Prefer [tipsFor] for packs.
  String? tipFor(String answer) {
    final tips = tipsFor(answer);
    if (tips.isEmpty) return null;
    return tips.first;
  }

  /// Parse etymology.json value: legacy `string` or pack `string[]`.
  static List<String> parseTips(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return const [];
      return [t];
    }
    return const [];
  }
}
