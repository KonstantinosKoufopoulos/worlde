import 'dart:convert';

import 'package:flutter/services.dart';

class DictRepository {
  DictRepository._();
  static final DictRepository instance = DictRepository._();

  List<String> answers = const [];
  Set<String> guesses = const {};
  Map<String, String> etymology = const {};

  bool get isLoaded => answers.isNotEmpty;

  Future<void> load() async {
    final answersRaw =
        await rootBundle.loadString('assets/dict/answers.json');
    final guessesRaw =
        await rootBundle.loadString('assets/dict/guesses.json');
    final etyRaw =
        await rootBundle.loadString('assets/dict/etymology.json');

    answers = (jsonDecode(answersRaw) as List).cast<String>();
    guesses = (jsonDecode(guessesRaw) as List).cast<String>().toSet();
    etymology = (jsonDecode(etyRaw) as Map).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
  }

  /// UTC days since 2026-01-01.
  static int dayIndex([DateTime? now]) {
    final epoch = DateTime.utc(2026, 1, 1);
    final utc = (now ?? DateTime.now()).toUtc();
    return utc.difference(epoch).inDays;
  }

  String answerForDay(int dayIndex) {
    if (answers.isEmpty) {
      throw StateError('Dictionary not loaded');
    }
    final idx = dayIndex % answers.length;
    // Dart % can be negative; normalize
    final safe = idx < 0 ? idx + answers.length : idx;
    return answers[safe];
  }

  bool isValidGuess(String matchKey) => guesses.contains(matchKey);

  String? tipFor(String answer) {
    final tip = etymology[answer];
    if (tip == null || tip.trim().isEmpty) return null;
    return tip.trim();
  }
}
