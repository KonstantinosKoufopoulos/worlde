import 'package:flutter/foundation.dart';

// Web has no dart:io → stub only. VM platforms get the IO selector, which
// uses Google UMP on Android only (iOS / desktop / tests → stub).
import 'consent_service_stub.dart'
    if (dart.library.io) 'consent_service_io.dart' as platform;

/// GDPR / privacy consent (Google User Messaging Platform on Android).
///
/// This interface has **no** google_mobile_ads dependency so the web build
/// never pulls in the SDK. Implementations must never throw: errors are
/// logged and the call completes normally (callers then rely on
/// [canRequestAds]).
abstract class ConsentService {
  /// `requestConsentInfoUpdate` → `loadAndShowConsentFormIfRequired`.
  ///
  /// Completes once consent is resolved for this session: the form was
  /// dismissed, was not required, or an error occurred. On first launch in
  /// the EEA/UK the UMP form is presented over the app UI.
  Future<void> gatherConsent();

  /// Whether ads may be requested (cached from a previous session until
  /// [gatherConsent] refreshes it).
  Future<bool> canRequestAds();

  /// True only when UMP says a privacy options entry point is required.
  Future<bool> isPrivacyOptionsRequired();

  /// Presents the UMP privacy options form; completes when it closes.
  Future<void> showPrivacyOptionsForm();
}

/// Web / desktop / iOS-for-now / `flutter test`: no UMP, no real ads.
/// Ads (the instant stub) are always allowed; no privacy options entry.
class StubConsentService implements ConsentService {
  @override
  Future<void> gatherConsent() async {}

  @override
  Future<bool> canRequestAds() async => true;

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptionsForm() async {}
}

/// Debug-only UMP overrides, set with `--dart-define`:
///
/// ```
/// flutter run --dart-define=UMP_DEBUG_EEA=true \
///   --dart-define=UMP_TEST_DEVICE_ID=<hashed id from logcat>
/// ```
///
/// Ignored in release/profile builds (see [umpDebugSettingsEnabled]).
class UmpDebugConfig {
  UmpDebugConfig._();

  /// Force the EEA geography so the GDPR form appears on a test device.
  static const bool forceEea = bool.fromEnvironment('UMP_DEBUG_EEA');

  /// Comma-separated hashed test device IDs (UMP prints the ID in logcat).
  /// Emulators are test devices by default and need no ID.
  static const String testDeviceIdsRaw =
      String.fromEnvironment('UMP_TEST_DEVICE_ID');

  static List<String> get testDeviceIds => parseTestDeviceIds(testDeviceIdsRaw);

  /// True only for debug builds with `UMP_DEBUG_EEA=true`.
  static bool get enabled =>
      umpDebugSettingsEnabled(debugMode: kDebugMode, forceEea: forceEea);
}

/// Debug geography is applied only when both flags are set. Release builds
/// (`debugMode == false`) never use UMP debug settings.
@visibleForTesting
bool umpDebugSettingsEnabled({required bool debugMode, required bool forceEea}) =>
    debugMode && forceEea;

@visibleForTesting
List<String> parseTestDeviceIds(String raw) => raw
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// Platform-appropriate consent service: UMP on Android, stub elsewhere.
ConsentService createConsentService() => platform.createPlatformConsentService();
