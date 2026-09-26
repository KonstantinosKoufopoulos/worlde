import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads/ads_consent_controller.dart';
import 'ads/consent_service.dart';
import 'ads/rewarded_ad_service.dart';
import 'app.dart';
import 'data/hive_boxes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();

  // Android: UMP consent first (form over the UI on first launch in EEA/UK),
  // then — only if canRequestAds() — MobileAds init + rewarded preload.
  // Web / desktop / iOS: stub services, no SDK.
  final rewardedAds = createRewardedAdService();
  final adsConsent = AdsConsentController(
    consent: createConsentService(),
    ads: rewardedAds,
  );

  runApp(
    ProviderScope(
      overrides: [
        rewardedAdServiceProvider.overrideWithValue(rewardedAds),
        adsConsentControllerProvider.overrideWith((ref) => adsConsent),
      ],
      child: const LeximeraApp(),
    ),
  );

  // Non-blocking: the UI renders immediately; UMP presents its form on top.
  unawaited(adsConsent.start());
}
