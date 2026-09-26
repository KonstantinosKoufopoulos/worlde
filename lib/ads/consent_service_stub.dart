// Web build: never imports google_mobile_ads (it depends on dart:io).
import 'consent_service.dart';

ConsentService createPlatformConsentService() => StubConsentService();
