import 'dart:io' show Platform;

import 'admob_rewarded_ad_service.dart';
import 'rewarded_ad_service.dart';
import 'stub_rewarded_ad_service.dart';

/// Android → AdMob. iOS (not wired yet), desktop and `flutter test` → stub.
RewardedAdService createPlatformRewardedAdService() {
  if (Platform.isAndroid) return AdMobRewardedAdService();
  return StubRewardedAdService();
}
