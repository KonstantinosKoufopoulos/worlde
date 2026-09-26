import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leximera/ads/ads_consent_controller.dart';
import 'package:leximera/ads/consent_service.dart';
import 'package:leximera/ads/rewarded_ad_service.dart';
import 'package:leximera/ui/privacy_options_action.dart';

/// Scriptable UMP stand-in.
class FakeConsentService implements ConsentService {
  FakeConsentService({
    this.previousSessionCanRequest = false,
    this.afterGatherCanRequest = false,
    this.afterPrivacyFormCanRequest,
    this.privacyRequired = false,
    this.gatherThrows = false,
  });

  bool previousSessionCanRequest;
  bool afterGatherCanRequest;
  bool? afterPrivacyFormCanRequest;
  bool privacyRequired;
  bool gatherThrows;

  bool _gathered = false;
  bool _privacyShown = false;
  int gatherCalls = 0;
  int privacyFormCalls = 0;
  int canRequestCalls = 0;

  /// Lets a test hold the consent form open.
  Completer<void>? gatherGate;

  @override
  Future<void> gatherConsent() async {
    gatherCalls++;
    if (gatherGate != null) await gatherGate!.future;
    if (gatherThrows) throw StateError('network');
    _gathered = true;
  }

  @override
  Future<bool> canRequestAds() async {
    canRequestCalls++;
    if (_privacyShown && afterPrivacyFormCanRequest != null) {
      return afterPrivacyFormCanRequest!;
    }
    return _gathered ? afterGatherCanRequest : previousSessionCanRequest;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptionsForm() async {
    privacyFormCalls++;
    _privacyShown = true;
  }
}

/// Counts SDK-ish calls; grants on show like a successful rewarded ad.
class CountingAds implements RewardedAdService {
  int initCalls = 0;
  int loadCalls = 0;
  int showCalls = 0;

  @override
  bool get usesRealAds => true;
  @override
  bool get isReady => initCalls > 0;
  @override
  Future<void> init() async {
    initCalls++;
    load();
  }

  @override
  void load() => loadCalls++;
  @override
  void dispose() {}

  @override
  Future<RewardedAdOutcome> show({
    required VoidCallback onUserEarnedReward,
  }) async {
    showCalls++;
    onUserEarnedReward();
    return RewardedAdOutcome.rewarded;
  }
}

void main() {
  group('AdsConsentController', () {
    test('canRequestAds false → ads never initialised or loaded', () async {
      final consent = FakeConsentService();
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      await c.start();
      expect(consent.gatherCalls, 1);
      expect(ads.initCalls, 0);
      expect(ads.loadCalls, 0);
      expect(c.adsInitialized, isFalse);
      expect(c.adsAllowed, isFalse);
    });

    test('gather error + canRequestAds false → no init, no crash', () async {
      final consent = FakeConsentService(gatherThrows: true);
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      await c.start();
      expect(ads.initCalls, 0);
      expect(c.adsAllowed, isFalse);
    });

    test('no init before consent resolves (first launch)', () async {
      final consent = FakeConsentService(afterGatherCanRequest: true)
        ..gatherGate = Completer<void>();
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      final started = c.start();
      await pumpEventQueue();
      // Form still open, previous session said no → nothing initialised.
      expect(ads.initCalls, 0);
      expect(ads.loadCalls, 0);
      consent.gatherGate!.complete();
      await started;
      expect(ads.initCalls, 1);
      expect(c.adsAllowed, isTrue);
    });

    test('initialised exactly once when parallel check and form both say true',
        () async {
      final consent = FakeConsentService(
        previousSessionCanRequest: true,
        afterGatherCanRequest: true,
      );
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      await Future.wait([c.start(), c.start()]);
      expect(consent.canRequestCalls, greaterThanOrEqualTo(2));
      expect(ads.initCalls, 1);
      expect(ads.loadCalls, 1);
      await c.showPrivacyOptions();
      expect(ads.initCalls, 1, reason: 'privacy form must not re-init');
    });

    test('returning user: previous-session consent inits before form resolves',
        () async {
      final consent = FakeConsentService(
        previousSessionCanRequest: true,
        afterGatherCanRequest: true,
      )..gatherGate = Completer<void>();
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      final started = c.start();
      await pumpEventQueue();
      expect(ads.initCalls, 1);
      consent.gatherGate!.complete();
      await started;
      expect(ads.initCalls, 1);
    });

    test('privacy options form → consent now allowed → init once', () async {
      final consent = FakeConsentService(
        privacyRequired: true,
        afterPrivacyFormCanRequest: true,
      );
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      await c.start();
      expect(ads.initCalls, 0);
      expect(c.privacyOptionsRequired, isTrue);
      await c.showPrivacyOptions();
      expect(consent.privacyFormCalls, 1);
      expect(ads.initCalls, 1);
      expect(c.adsAllowed, isTrue);
    });

    test('CTA gives no letter and never shows an ad when ads cannot be requested',
        () async {
      final consent = FakeConsentService();
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      await c.start();
      var grants = 0;
      final outcome = await c.runRewardedLetter(grant: () => grants++);
      expect(outcome, RewardedAdOutcome.notReady);
      expect(grants, 0);
      expect(ads.showCalls, 0);
      expect(ads.initCalls, 0);
      expect(consent.gatherCalls, 1, reason: 'CTA must not trigger the form');
      expect(consent.privacyFormCalls, 0);
    });

    test('CTA before start resolves → notReady, no letter', () async {
      final consent = FakeConsentService(afterGatherCanRequest: true)
        ..gatherGate = Completer<void>();
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      unawaited(c.start());
      await pumpEventQueue();
      var grants = 0;
      expect(await c.runRewardedLetter(grant: () => grants++),
          RewardedAdOutcome.notReady);
      expect(grants, 0);
      consent.gatherGate!.complete();
    });

    test('CTA with consent → rewarded letter granted once', () async {
      final consent = FakeConsentService(afterGatherCanRequest: true);
      final ads = CountingAds();
      final c = AdsConsentController(consent: consent, ads: ads);
      await c.start();
      var grants = 0;
      final outcome = await c.runRewardedLetter(grant: () => grants++);
      expect(outcome, RewardedAdOutcome.rewarded);
      expect(grants, 1);
      expect(ads.showCalls, 1);
    });

    test('stub consent (web/desktop/tests) allows the instant stub ads', () async {
      final consent = StubConsentService();
      expect(await consent.canRequestAds(), isTrue);
      expect(await consent.isPrivacyOptionsRequired(), isFalse);
      expect(createConsentService(), isA<StubConsentService>());
    });
  });

  group('UMP debug settings', () {
    test('only in debug builds with the flag; default off', () {
      expect(umpDebugSettingsEnabled(debugMode: true, forceEea: true), isTrue);
      expect(umpDebugSettingsEnabled(debugMode: true, forceEea: false), isFalse);
      expect(umpDebugSettingsEnabled(debugMode: false, forceEea: true), isFalse);
      expect(UmpDebugConfig.forceEea, isFalse);
      expect(UmpDebugConfig.enabled, isFalse);
    });

    test('test device ids parsing', () {
      expect(parseTestDeviceIds(''), isEmpty);
      expect(parseTestDeviceIds(' A1 , B2,,'), ['A1', 'B2']);
    });
  });

  group('«Επιλογές απορρήτου»', () {
    Future<FakeConsentService> pump(
      WidgetTester tester, {
      required bool required,
    }) async {
      final consent = FakeConsentService(privacyRequired: required);
      final controller =
          AdsConsentController(consent: consent, ads: CountingAds());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adsConsentControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: const [PrivacyOptionsAction()]),
              body: const PrivacyOptionsTile(),
            ),
          ),
        ),
      );
      await tester.runAsync(controller.start);
      await tester.pump();
      expect(controller.privacyOptionsRequired, required);
      return consent;
    }

    testWidgets('hidden when privacy options not required', (tester) async {
      await pump(tester, required: false);
      expect(find.byTooltip(privacyOptionsLabel), findsNothing);
      expect(find.text(privacyOptionsLabel), findsNothing);
    });

    testWidgets('visible when required and opens the privacy form',
        (tester) async {
      final consent = await pump(tester, required: true);
      expect(find.byTooltip(privacyOptionsLabel), findsOneWidget);
      expect(find.text(privacyOptionsLabel), findsOneWidget);

      await tester.tap(find.byTooltip(privacyOptionsLabel));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      expect(consent.privacyFormCalls, 1);
    });
  });
}
