import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/ads_consent_controller.dart';

const privacyOptionsLabel = 'Επιλογές απορρήτου';

/// App-bar action «Επιλογές απορρήτου», next to the theme toggle.
///
/// Rendered only when UMP reports the privacy options entry point as
/// required (Android, EEA/UK users). Opens the UMP privacy options form so
/// the user can change their ad consent choice.
class PrivacyOptionsAction extends ConsumerWidget {
  const PrivacyOptionsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(
      adsConsentControllerProvider.select((c) => c.privacyOptionsRequired),
    );
    if (!required) return const SizedBox.shrink();
    return IconButton(
      tooltip: privacyOptionsLabel,
      onPressed: () =>
          ref.read(adsConsentControllerProvider).showPrivacyOptions(),
      icon: const Icon(Icons.privacy_tip_outlined),
    );
  }
}

/// Same entry as a list tile (used in the play screen's info sheet, where the
/// app bar has no room for another icon).
class PrivacyOptionsTile extends ConsumerWidget {
  const PrivacyOptionsTile({super.key, this.onBeforeOpen});

  /// E.g. close the bottom sheet before the UMP form is presented.
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(
      adsConsentControllerProvider.select((c) => c.privacyOptionsRequired),
    );
    if (!required) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text(privacyOptionsLabel),
      onTap: () {
        final controller = ref.read(adsConsentControllerProvider);
        onBeforeOpen?.call();
        controller.showPrivacyOptions();
      },
    );
  }
}
