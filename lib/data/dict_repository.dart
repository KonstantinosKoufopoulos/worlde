import 'dart:convert';

import 'package:flutter/services.dart';

import 'pack_meta.dart';
import 'word_dict.dart';

class DictRepository {
  DictRepository._();
  static final DictRepository instance = DictRepository._();

  /// Shipped thematic packs (assets under assets/dict/packs/{id}/).
  static const catalogPackIds = ['mythology'];

  WordDict? _main;
  final Map<String, WordDict> _packs = {};
  final Map<String, PackMeta> _metas = {};

  WordDict get main {
    final m = _main;
    if (m == null) throw StateError('Dictionary not loaded');
    return m;
  }

  bool get isLoaded => _main != null && !_main!.isEmpty;

  /// Back-compat accessors used by older call sites.
  List<String> get answers => main.answers;
  Set<String> get guesses => main.guesses;
  Map<String, String> get etymology => main.etymology;

  Future<void> load() async {
    if (_main != null) return;
    _main = await _loadWordDict('assets/dict');
  }

  Future<List<PackMeta>> loadCatalog() async {
    final out = <PackMeta>[];
    for (final id in catalogPackIds) {
      out.add(await loadPackMeta(id));
    }
    return out;
  }

  Future<PackMeta> loadPackMeta(String packId) async {
    final cached = _metas[packId];
    if (cached != null) return cached;
    final raw =
        await rootBundle.loadString('assets/dict/packs/$packId/meta.json');
    final meta = PackMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _metas[packId] = meta;
    return meta;
  }

  Future<WordDict> loadPack(String packId) async {
    final cached = _packs[packId];
    if (cached != null) return cached;
    final dict = await _loadWordDict('assets/dict/packs/$packId');
    _packs[packId] = dict;
    await loadPackMeta(packId);
    return dict;
  }

  WordDict dictFor({String? packId}) {
    if (packId == null || packId.isEmpty) return main;
    final pack = _packs[packId];
    if (pack == null) {
      throw StateError('Pack "$packId" not loaded');
    }
    return pack;
  }

  /// UTC days since 2026-01-01.
  static int dayIndex([DateTime? now]) {
    final epoch = DateTime.utc(2026, 1, 1);
    final utc = (now ?? DateTime.now()).toUtc();
    return utc.difference(epoch).inDays;
  }

  String answerForDay(int dayIndex) => main.answerForDay(dayIndex);

  bool isValidGuess(String matchKey) => main.isValidGuess(matchKey);

  String? tipFor(String answer) => main.tipFor(answer);

  static Future<WordDict> _loadWordDict(String assetDir) async {
    final answersRaw =
        await rootBundle.loadString('$assetDir/answers.json');
    final guessesRaw =
        await rootBundle.loadString('$assetDir/guesses.json');
    final etyRaw =
        await rootBundle.loadString('$assetDir/etymology.json');

    return WordDict(
      answers: (jsonDecode(answersRaw) as List).cast<String>(),
      guesses: (jsonDecode(guessesRaw) as List).cast<String>().toSet(),
      etymology: (jsonDecode(etyRaw) as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }
}
