import 'package:flutter/foundation.dart';

/// Public AdMob identifiers for Λεξήμερα (Android / Google Play).
///
/// These IDs are not secrets — they ship inside the app binary.
/// The App ID also lives in `android/app/src/main/AndroidManifest.xml`
/// as `com.google.android.gms.ads.APPLICATION_ID`.
class AdConfig {
  AdConfig._();

  /// Production AdMob App ID (Android).
  static const androidAppId = 'ca-app-pub-1774874652706103~3930211495';

  /// Production rewarded ad unit («Γράμμα με διαφήμιση»).
  static const androidRewardedProdUnitId =
      'ca-app-pub-1774874652706103/4764695297';

  /// Google's official Android test rewarded unit — always safe to request.
  static const androidRewardedTestUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Release builds use the production unit; debug/profile use the Google
  /// test unit so we never serve (or click) real ads while developing.
  static String get androidRewardedUnitId => rewardedUnitIdFor(
        releaseMode: kReleaseMode,
      );

  @visibleForTesting
  static String rewardedUnitIdFor({required bool releaseMode}) =>
      releaseMode ? androidRewardedProdUnitId : androidRewardedTestUnitId;
}
