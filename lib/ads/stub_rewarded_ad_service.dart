import 'package:flutter/foundation.dart';

import 'rewarded_ad_service.dart';

/// Web / desktop / iOS-for-now: no Mobile Ads SDK. Keeps the pre-AdMob
/// behaviour — the reward is granted instantly.
class StubRewardedAdService implements RewardedAdService {
  @override
  bool get usesRealAds => false;

  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  void load() {}

  @override
  Future<RewardedAdOutcome> show({
    required VoidCallback onUserEarnedReward,
  }) async {
    onUserEarnedReward();
    return RewardedAdOutcome.rewarded;
  }

  @override
  void dispose() {}
}
