import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/normalize.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import 'board.dart';
import 'keyboard.dart';
import 'share.dart';
import 'theme.dart';
import 'tip_card.dart';
import 'win_confetti.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictAsync = ref.watch(dictProvider);

    return dictAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Σφάλμα φόρτωσης: $e')),
      ),
      data: (_) => const _PlayView(),
    );
  }
}

class _PlayView extends ConsumerStatefulWidget {
  const _PlayView();

  @override
  ConsumerState<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends ConsumerState<_PlayView> {
  final _focus = FocusNode();
  bool _confettiPlaying = false;
  bool _shareVisible = false;
  Timer? _shareDelayTimer;
  bool _handledInitialFinish = false;

  static const _shareAfterTipDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _shareDelayTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final ctrl = ref.read(gameControllerProvider.notifier);

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      ctrl.onKey('ENTER');
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      ctrl.onKey('BACK');
      return;
    }

    final ch = event.character;
    if (ch == null || ch.isEmpty) return;
    // Accept Greek (and composed) letters; ignore latin/digits
    final probe = normalizeGreekWord('$chαααα'.substring(0, 5));
    if (probe == null) return;
    ctrl.onKey(probe[0]);
  }

  Future<void> _share() async {
    final state = ref.read(gameControllerProvider);
    await copyShareText(state);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Αντιγράφηκε στο πρόχειρο')),
    );
  }

  void _scheduleShareVisible({required bool afterTip}) {
    _shareDelayTimer?.cancel();
    if (!afterTip) {
      setState(() => _shareVisible = true);
      return;
    }
    // Tip is shown immediately in the tree; enable Share 400ms after that.
    _shareDelayTimer = Timer(_shareAfterTipDelay, () {
      if (!mounted) return;
      setState(() => _shareVisible = true);
    });
  }

  void _onWon({required bool celebrate}) {
    if (celebrate) {
      // Soft haptic (no-ops on unsupported platforms / web — fine).
      HapticFeedback.lightImpact();
      setState(() {
        _confettiPlaying = true;
        _shareVisible = false;
      });
      // Confetti self-ends at 1.2s; clear flag so a later win can retrigger.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _confettiPlaying = false);
      });
    }
    _scheduleShareVisible(afterTip: true);
  }

  void _syncFinishFromState(GameState state) {
    if (_handledInitialFinish) return;
    _handledInitialFinish = true;
    if (state.status == GameStatus.won) {
      // Restored win: tip already in tree — delay Share, skip confetti/haptic.
      _scheduleShareVisible(afterTip: true);
    } else if (state.status == GameStatus.lost) {
      // Field assign only — may run during build on first frame.
      _shareVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    _syncFinishFromState(state);

    ref.listen<GameState>(gameControllerProvider, (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            duration: const Duration(seconds: 2),
          ),
        );
        ref.read(gameControllerProvider.notifier).clearMessage();
      }

      final justWon =
          next.status == GameStatus.won && prev?.status != GameStatus.won;
      final justLost =
          next.status == GameStatus.lost && prev?.status != GameStatus.lost;

      if (justWon) {
        _onWon(celebrate: true);
      } else if (justLost) {
        _shareDelayTimer?.cancel();
        setState(() => _shareVisible = true);
      }
    });

    final showTip = state.status == GameStatus.won &&
        state.etymologyTip != null &&
        state.etymologyTip!.isNotEmpty;

    final showShare = state.isFinished && _shareVisible;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onHardwareKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Λεξήμερα',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '🔥 ${state.streak}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (showShare)
              IconButton(
                tooltip: 'Κοινοποίηση',
                onPressed: _share,
                icon: const Icon(Icons.share_outlined),
              ),
            IconButton(
              tooltip: tooltipForThemeMode(themeMode),
              onPressed: () =>
                  ref.read(themeModeProvider.notifier).cycle(),
              icon: Icon(iconForThemeMode(themeMode)),
            ),
            IconButton(
              tooltip: 'Πληροφορίες',
              onPressed: () => _showHelp(context, state.dayIndex),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ημερήσιο #${state.dayIndex + 1}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  if (showTip) TipCard(tip: state.etymologyTip!),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: GameBoard(rows: state.rows),
                    ),
                  ),
                  if (showShare)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: _share,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: Text(
                          state.status == GameStatus.won
                              ? 'Κοινοποίηση αποτελέσματος'
                              : 'Κοινοποίηση · λέξη: ${state.answer}',
                        ),
                      ),
                    ),
                  GameKeyboard(
                    keyStates: state.keyStates,
                    onKey: (k) =>
                        ref.read(gameControllerProvider.notifier).onKey(k),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Positioned.fill(
              child: WinConfetti(playing: _confettiPlaying),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context, int dayIndex) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Πώς παίζεται',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Μάντεψε τη λέξη της ημέρας σε 6 προσπάθειες.\n'
                'Πράσινο = σωστό γράμμα στη σωστή θέση.\n'
                'Κίτρινο = υπάρχει στη λέξη, άλλη θέση.\n'
                'Γκρι = δεν υπάρχει στη λέξη.\n\n'
                'Νέα λέξη κάθε μέρα (UTC).',
              ),
              const SizedBox(height: 8),
              Text('Σημερινό παζλ: #${dayIndex + 1}'),
            ],
          ),
        );
      },
    );
  }
}
