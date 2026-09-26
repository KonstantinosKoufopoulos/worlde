// Web build: never imports google_mobile_ads (it depends on dart:io).
import 'rewarded_ad_service.dart';
import 'stub_rewarded_ad_service.dart';

RewardedAdService createPlatformRewardedAdService() => StubRewardedAdService();
