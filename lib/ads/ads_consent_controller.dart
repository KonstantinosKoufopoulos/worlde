import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'consent_service.dart';
import 'rewarded_ad_service.dart';

/// Gates the Mobile Ads SDK behind UMP consent.
///
/// App start ([start]):
/// 1. `gatherConsent()` — requestConsentInfoUpdate → loadAndShowConsentFormIfRequired
///    (the form is shown over the already-rendered UI on first launch in the
///    EEA/UK, before the player reaches a puzzle).
/// 2. In parallel, `canRequestAds()` from the previous session, so returning
///    users get ads initialised without waiting for the network round-trip.
/// 3. After the form resolves, `canRequestAds()` again.
///
/// Only when `canRequestAds()` is true is [RewardedAdService.init] called
/// (MobileAds.initialize + first preload) — at most once per process, even
/// if several checks report true. Nothing ever loads an ad before that.
///
/// The consent form is never triggered from the «Γράμμα με διαφήμιση» CTA;
/// if ads can't be requested, [runRewardedLetter] returns
/// [RewardedAdOutcome.notReady] without touching the SDK.
class AdsConsentController extends ChangeNotifier {
  AdsConsentController({
    required ConsentService consent,
    required RewardedAdService ads,
  })  : _consent = consent,
        _ads = ads;

  final ConsentService _consent;
  final RewardedAdService _ads;

  Future<void>? _startFuture;
  bool _adsInitStarted = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _privacyFormShowing = false;
  bool _disposed = false;

  /// True once the ads SDK init was triggered (after consent allowed it).
  bool get adsInitialized => _adsInitStarted;

  /// Last known UMP `canRequestAds()` result.
  bool get canRequestAds => _canRequestAds;

  /// Rewarded ads may be shown: consent allows it and the SDK was initialised.
  bool get adsAllowed => _adsInitStarted && _canRequestAds;

  /// Show «Επιλογές απορρήτου» (UMP status == required; Android only).
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Idempotent app-start consent flow. Never throws.
  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    // Kick off the consent update first, then the previous-session check.
    final gather = _safe(_consent.gatherConsent);
    final previousSession = _checkAndMaybeInitAds();
    await gather;
    await previousSession;
    await _checkAndMaybeInitAds();
    await refreshPrivacyOptionsStatus();
  }

  /// Opens the UMP privacy options form (from «Επιλογές απορρήτου»). When it
  /// closes, initialises ads if consent now allows it and re-reads the status.
  Future<void> showPrivacyOptions() async {
    if (_privacyFormShowing) return;
    _privacyFormShowing = true;
    try {
      await _safe(_consent.showPrivacyOptionsForm);
    } finally {
      _privacyFormShowing = false;
    }
    await _checkAndMaybeInitAds();
    await refreshPrivacyOptionsStatus();
  }

  Future<void> refreshPrivacyOptionsStatus() async {
    bool required;
    try {
      required = await _consent.isPrivacyOptionsRequired();
    } catch (e) {
      debugPrint('Privacy options status failed: $e');
      required = false;
    }
    if (required != _privacyOptionsRequired) {
      _privacyOptionsRequired = required;
      _notify();
    }
  }

  /// «Γράμμα με διαφήμιση»: no consent / not resolved → notReady, no letter,
  /// no SDK call. Otherwise the normal rewarded flow.
  Future<RewardedAdOutcome> runRewardedLetter({required VoidCallback grant}) {
    if (!adsAllowed) return Future.value(RewardedAdOutcome.notReady);
    return runRewardedLetterFlow(ads: _ads, grant: grant);
  }

  Future<void> _checkAndMaybeInitAds() async {
    bool can;
    try {
      can = await _consent.canRequestAds();
    } catch (e) {
      debugPrint('canRequestAds failed: $e');
      can = false;
    }
    if (_disposed) return;
    if (can != _canRequestAds) {
      _canRequestAds = can;
      _notify();
    }
    if (can) _initAdsOnce();
  }

  void _initAdsOnce() {
    if (_adsInitStarted || _disposed) return;
    _adsInitStarted = true;
    _notify();
    unawaited(_safe(_ads.init));
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('Consent/ads step failed: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// App-wide controller. `main.dart` overrides this with an instance whose
/// [AdsConsentController.start] already runs from app launch.
final adsConsentControllerProvider =
    ChangeNotifierProvider<AdsConsentController>((ref) {
  final controller = AdsConsentController(
    consent: createConsentService(),
    ads: ref.watch(rewardedAdServiceProvider),
  );
  unawaited(controller.start());
  return controller;
});
