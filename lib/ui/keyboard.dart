import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'theme.dart';

/// Greek 3-row keyboard + Enter + ⌫. Min touch targets ≥ 44.
class GameKeyboard extends StatelessWidget {
  const GameKeyboard({
    super.key,
    required this.keyStates,
    required this.onKey,
  });

  final Map<String, LetterState> keyStates;
  final void Function(String key) onKey;

  static const row1 = ['Ε', 'Ρ', 'Τ', 'Υ', 'Θ', 'Ι', 'Ο', 'Π'];
  static const row2 = ['Α', 'Σ', 'Δ', 'Φ', 'Γ', 'Η', 'Ξ', 'Κ', 'Λ'];
  static const row3Letters = ['Ζ', 'Χ', 'Ψ', 'Ω', 'Β', 'Ν', 'Μ'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _letterRow(row1),
          const SizedBox(height: 6),
          _letterRow(row2),
          const SizedBox(height: 6),
          Row(
            children: [
              _SpecialKey(label: 'Enter', onTap: () => onKey('ENTER')),
              const SizedBox(width: 4),
              for (var i = 0; i < row3Letters.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _LetterKey(
                    letter: row3Letters[i],
                    state: keyStates[row3Letters[i]] ?? LetterState.empty,
                    onTap: () => onKey(row3Letters[i]),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              _SpecialKey(label: '⌫', onTap: () => onKey('BACK')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _letterRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _LetterKey(
              letter: keys[i],
              state: keyStates[keys[i]] ?? LetterState.empty,
              onTap: () => onKey(keys[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _LetterKey extends StatelessWidget {
  const _LetterKey({
    required this.letter,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final LetterState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final evaluated = state == LetterState.correct ||
        state == LetterState.present ||
        state == LetterState.absent;
    final bg = evaluated
        ? colorForLetterState(state, brightness)
        : (brightness == Brightness.dark
            ? const Color(0xFF818384)
            : const Color(0xFFD3D6DA));
    final fg = evaluated
        ? foregroundForLetterState(state)
        : Theme.of(context).colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 32),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialKey extends StatelessWidget {
  const _SpecialKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.dark
        ? const Color(0xFF818384)
        : const Color(0xFFD3D6DA);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 52),
          child: SizedBox(
            height: 52,
            width: 56,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: label == '⌫' ? 18 : 11,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
