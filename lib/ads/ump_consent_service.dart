import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_service.dart';

/// Android GDPR consent via Google UMP (bundled with google_mobile_ads).
///
/// The form only appears if a GDPR message is **published** in the AdMob
/// console (Privacy & messaging) and the user is in a regulated region
/// (EEA/UK/CH), or when forced with [UmpDebugConfig] in a debug build.
class UmpConsentService implements ConsentService {
  ConsentRequestParameters _params() {
    if (!UmpDebugConfig.enabled) return ConsentRequestParameters();
    final ids = UmpDebugConfig.testDeviceIds;
    debugPrint('UMP debug: forcing EEA geography (test ids: $ids)');
    return ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: ids.isEmpty ? null : ids,
      ),
    );
  }

  @override
  Future<void> gatherConsent() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        _params(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('UMP form error ${formError.errorCode}: '
                    '${formError.message}');
              }
              finish();
            });
          } catch (e) {
            debugPrint('UMP loadAndShowConsentFormIfRequired failed: $e');
          }
          finish();
        },
        (error) {
          debugPrint('UMP consent info update failed '
              '${error.errorCode}: ${error.message}');
          finish();
        },
      );
    } catch (e) {
      debugPrint('UMP requestConsentInfoUpdate threw: $e');
      finish();
    }
    return done.future;
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('UMP canRequestAds failed: $e');
      return false;
    }
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('UMP privacy options status failed: $e');
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    final done = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('UMP privacy options error ${formError.errorCode}: '
              '${formError.message}');
        }
        if (!done.isCompleted) done.complete();
      });
    } catch (e) {
      debugPrint('UMP showPrivacyOptionsForm failed: $e');
    }
    if (!done.isCompleted) done.complete();
    return done.future;
  }
}
