import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads/rewarded_ad_service.dart';
import 'app.dart';
import 'data/hive_boxes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();

  // Android: init Mobile Ads SDK + preload first rewarded ad (non-blocking).
  // Web / desktop / iOS: stub service, no SDK.
  final rewardedAds = createRewardedAdService();
  unawaited(rewardedAds.init());

  runApp(
    ProviderScope(
      overrides: [
        rewardedAdServiceProvider.overrideWithValue(rewardedAds),
      ],
      child: const LeximeraApp(),
    ),
  );
}
