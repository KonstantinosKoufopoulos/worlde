import 'dart:io' show Platform;

import 'consent_service.dart';
import 'ump_consent_service.dart';

/// Android → Google UMP. iOS (not wired yet), desktop and `flutter test` → stub.
ConsentService createPlatformConsentService() {
  if (Platform.isAndroid) return UmpConsentService();
  return StubConsentService();
}
