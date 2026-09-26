import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Web has no dart:io → stub only. VM platforms (Android, iOS, desktop, tests)
// get the IO implementation, which uses the Mobile Ads SDK on Android only.
import 'rewarded_ad_service_stub.dart'
    if (dart.library.io) 'rewarded_ad_service_io.dart' as platform;

/// Result of a rewarded ad attempt.
enum RewardedAdOutcome {
  /// User earned the reward (onUserEarnedReward fired).
  rewarded,

  /// Ad was shown but closed before the reward was earned.
  dismissedWithoutReward,

  /// No ad loaded yet (a load is triggered); nothing was shown.
  notReady,

  /// The SDK failed to present the ad.
  failedToShow,
}

/// Loads and shows rewarded ads.
///
/// Contract for [show]: [onUserEarnedReward] is invoked **only** when the ad
/// SDK reports the reward (at most once per call). Cancel / fail / not-ready
/// never invoke it.
abstract class RewardedAdService {
  /// True when this service uses the real Mobile Ads SDK (Android).
  bool get usesRealAds;

  /// True when an ad is loaded and [show] can present it immediately.
  bool get isReady;

  /// One-time SDK init (Android only) + first preload. Safe to call again.
  Future<void> init();

  /// Preload the next rewarded ad if none is loaded / loading.
  void load();

  /// Show the loaded ad. Completes after the ad closes (or fails / not ready).
  Future<RewardedAdOutcome> show({required VoidCallback onUserEarnedReward});

  void dispose();
}

/// Platform-appropriate service: AdMob on Android, instant stub elsewhere.
RewardedAdService createRewardedAdService() =>
    platform.createPlatformRewardedAdService();

/// App-wide service. `main.dart` overrides this with a pre-initialized
/// instance so the first ad is preloading before a pack is opened.
final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = createRewardedAdService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

/// «Γράμμα με διαφήμιση» flow: shows the ad and calls [grant] only from the
/// reward callback — exactly once even if the SDK reports twice.
/// Cancel / fail / not-ready → no letter.
Future<RewardedAdOutcome> runRewardedLetterFlow({
  required RewardedAdService ads,
  required VoidCallback grant,
}) async {
  var granted = false;
  final outcome = await ads.show(
    onUserEarnedReward: () {
      if (granted) return;
      granted = true;
      grant();
    },
  );
  return outcome;
}
