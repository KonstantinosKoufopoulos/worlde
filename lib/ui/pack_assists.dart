import 'package:flutter/material.dart';

import '../game/game_state.dart';

/// Pack-only Christos assists: rewarded letter CTA (up to 3×) + resign.
/// No tip stack / progressive tips.
class PackAssistsPanel extends StatelessWidget {
  const PackAssistsPanel({
    super.key,
    required this.rewardedLetterCount,
    required this.canGrantRewardedLetter,
    required this.onGrantRewardedLetter,
    required this.canGiveUp,
    required this.onGiveUp,
  });

  final int rewardedLetterCount;
  final bool canGrantRewardedLetter;
  final VoidCallback onGrantRewardedLetter;
  final bool canGiveUp;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = rewardedLetterCount.clamp(0, GameState.maxRewardedLetters);
    final max = GameState.maxRewardedLetters;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Γράμματα $used/$max',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed:
                  canGrantRewardedLetter ? onGrantRewardedLetter : null,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Γράμμα με διαφήμιση'),
            ),
          ),
          if (canGiveUp) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onGiveUp,
                style: TextButton.styleFrom(
                  foregroundColor:
                      scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: const Text('Παραίτηση'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
