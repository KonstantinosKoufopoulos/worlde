import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leximera/ads/ad_config.dart';
import 'package:leximera/ads/rewarded_ad_service.dart';
import 'package:leximera/ads/stub_rewarded_ad_service.dart';

/// Scripted fake: simulates what the SDK does during show().
class _FakeAds implements RewardedAdService {
  _FakeAds(this.outcome, {this.rewardCallbacks = 0});

  final RewardedAdOutcome outcome;
  final int rewardCallbacks;
  int showCalls = 0;

  @override
  bool get usesRealAds => true;
  @override
  bool get isReady => outcome != RewardedAdOutcome.notReady;
  @override
  Future<void> init() async {}
  @override
  void load() {}
  @override
  void dispose() {}

  @override
  Future<RewardedAdOutcome> show({
    required VoidCallback onUserEarnedReward,
  }) async {
    showCalls++;
    for (var i = 0; i < rewardCallbacks; i++) {
      onUserEarnedReward();
    }
    return outcome;
  }
}

void main() {
  test('debug/test builds use Google test rewarded unit; release uses prod', () {
    expect(
      AdConfig.rewardedUnitIdFor(releaseMode: false),
      'ca-app-pub-3940256099942544/5224354917',
    );
    expect(
      AdConfig.rewardedUnitIdFor(releaseMode: true),
      'ca-app-pub-1774874652706103/4764695297',
    );
    // flutter test runs in debug mode.
    expect(AdConfig.androidRewardedUnitId, AdConfig.androidRewardedTestUnitId);
    expect(AdConfig.androidAppId, 'ca-app-pub-1774874652706103~3930211495');
  });

  test('letter granted when reward earned', () async {
    var grants = 0;
    final outcome = await runRewardedLetterFlow(
      ads: _FakeAds(RewardedAdOutcome.rewarded, rewardCallbacks: 1),
      grant: () => grants++,
    );
    expect(outcome, RewardedAdOutcome.rewarded);
    expect(grants, 1);
  });

  test('duplicate reward callbacks grant only one letter', () async {
    var grants = 0;
    await runRewardedLetterFlow(
      ads: _FakeAds(RewardedAdOutcome.rewarded, rewardCallbacks: 2),
      grant: () => grants++,
    );
    expect(grants, 1);
  });

  test('cancel / fail / not ready → no letter', () async {
    for (final o in [
      RewardedAdOutcome.dismissedWithoutReward,
      RewardedAdOutcome.failedToShow,
      RewardedAdOutcome.notReady,
    ]) {
      var grants = 0;
      final outcome = await runRewardedLetterFlow(
        ads: _FakeAds(o),
        grant: () => grants++,
      );
      expect(outcome, o);
      expect(grants, 0, reason: '$o must not grant');
    }
  });

  test('web/desktop stub grants instantly without SDK', () async {
    final stub = StubRewardedAdService();
    expect(stub.usesRealAds, isFalse);
    var grants = 0;
    final outcome = await runRewardedLetterFlow(
      ads: stub,
      grant: () => grants++,
    );
    expect(outcome, RewardedAdOutcome.rewarded);
    expect(grants, 1);
  });

  test('non-Android VM (flutter test host) gets the stub service', () {
    expect(createRewardedAdService().usesRealAds, isFalse);
  });
}
