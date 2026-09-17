import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const settingsName = 'settings';

  static const keyLastPlayedDay = 'lastPlayedDay';
  static const keyStreak = 'streak';
  static const keyThemeMode = 'themeMode'; // system | light | dark
  static const keyBoardRows = 'boardRows'; // persisted guesses for today
  static const keyGameStatus = 'gameStatus'; // playing | won | lost
  static const keySavedDayIndex = 'savedDayIndex';

  static late Box settings;

  static Future<void> init() async {
    await Hive.initFlutter();
    settings = await Hive.openBox(settingsName);
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

  static String get themeMode =>
      settings.get(keyThemeMode, defaultValue: 'system') as String;

  static set themeMode(String v) => settings.put(keyThemeMode, v);
}
