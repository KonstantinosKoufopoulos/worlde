import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'rewarded_ad_service.dart';

/// Android rewarded ads via google_mobile_ads.
///
/// Debug/profile → Google test unit; release → production unit
/// (see [AdConfig.androidRewardedUnitId]). UMP / consent is a later ticket.
class AdMobRewardedAdService implements RewardedAdService {
  AdMobRewardedAdService({String? adUnitId})
      : _adUnitId = adUnitId ?? AdConfig.androidRewardedUnitId;

  final String _adUnitId;

  Future<void>? _initFuture;
  RewardedAd? _ad;
  bool _loading = false;
  bool _showing = false;
  bool _disposed = false;

  @override
  bool get usesRealAds => true;

  @override
  bool get isReady => _ad != null && !_showing;

  @override
  Future<void> init() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds init failed: $e');
    }
    load();
  }

  @override
  void load() {
    if (_disposed || _loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  @override
  Future<RewardedAdOutcome> show({
    required VoidCallback onUserEarnedReward,
  }) {
    final ad = _ad;
    if (ad == null || _showing) {
      unawaited(init());
      load();
      return Future.value(RewardedAdOutcome.notReady);
    }

    _ad = null;
    _showing = true;
    var earned = false;
    final done = Completer<RewardedAdOutcome>();

    void finish(RewardedAdOutcome outcome) {
      _showing = false;
      if (!done.isCompleted) done.complete(outcome);
      load(); // Reload after every show attempt.
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        finish(earned
            ? RewardedAdOutcome.rewarded
            : RewardedAdOutcome.dismissedWithoutReward);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        debugPrint('RewardedAd failed to show: $error');
        a.dispose();
        finish(earned
            ? RewardedAdOutcome.rewarded
            : RewardedAdOutcome.failedToShow);
      },
    );

    ad.show(
      onUserEarnedReward: (_, _) {
        if (earned) return;
        earned = true;
        onUserEarnedReward();
      },
    );

    return done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
  }
}
