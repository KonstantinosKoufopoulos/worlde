import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const settingsName = 'settings';

  static const keyLastPlayedDay = 'lastPlayedDay';
  static const keyStreak = 'streak';
  static const keyThemeMode = 'themeMode'; // system | light | dark
  static const keyBoardRows = 'boardRows'; // persisted guesses for today
  static const keyGameStatus = 'gameStatus'; // playing | won | lost
  static const keySavedDayIndex = 'savedDayIndex';
  static const keyManualTipReveal = 'manualTipReveal'; // tip1 free, pack puzzle
  static const keyAdTipUnlock = 'adTipUnlock'; // tip3 rewarded stub, pack
  static const keyGaveUp = 'gaveUp'; // pack give-up for current puzzle
  static const keyRewardedLetterUsed = 'rewardedLetterUsed'; // pack 1× letter ad
  static const keyRewardedLetterCol = 'rewardedLetterCol'; // column 0–4

  static late Box settings;

  static Future<void> init() async {
    await Hive.initFlutter();
    settings = await Hive.openBox(settingsName);
  }

  /// Main daily keys stay unprefixed. Pack progress uses `pack_<id>_…`
  /// so pack play never mutates the main streak / board.
  static String scopedKey(String? packId, String key) {
    if (packId == null || packId.isEmpty) return key;
    return 'pack_${packId}_$key';
  }

  static int get streak => settings.get(keyStreak, defaultValue: 0) as int;

  static set streak(int v) => settings.put(keyStreak, v);

  static int? get lastPlayedDay => settings.get(keyLastPlayedDay) as int?;

  static set lastPlayedDay(int? v) {
    if (v == null) {
      settings.delete(keyLastPlayedDay);
    } else {
      settings.put(keyLastPlayedDay, v);
    }
  }

  static int streakFor(String? packId) =>
      settings.get(scopedKey(packId, keyStreak), defaultValue: 0) as int;

  static void setStreakFor(String? packId, int v) =>
      settings.put(scopedKey(packId, keyStreak), v);

  static int? lastPlayedDayFor(String? packId) =>
      settings.get(scopedKey(packId, keyLastPlayedDay)) as int?;

  static void setLastPlayedDayFor(String? packId, int? v) {
    final k = scopedKey(packId, keyLastPlayedDay);
    if (v == null) {
      settings.delete(k);
    } else {
      settings.put(k, v);
    }
  }

  static dynamic getScoped(String? packId, String key) =>
      settings.get(scopedKey(packId, key));

  static void putScoped(String? packId, String key, dynamic value) =>
      settings.put(scopedKey(packId, key), value);

  static void deleteScoped(String? packId, String key) =>
      settings.delete(scopedKey(packId, key));

  static String get themeMode =>
      settings.get(keyThemeMode, defaultValue: 'system') as String;

  static set themeMode(String v) => settings.put(keyThemeMode, v);
}
