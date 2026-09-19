import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/normalize.dart';
import '../data/hive_boxes.dart';
import '../data/pack_meta.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import 'board.dart';
import 'keyboard.dart';
import 'share.dart';
import 'theme.dart';
import 'progressive_tips.dart';
import 'tip_card.dart';
import 'win_confetti.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final dictAsync = ref.watch(dictProvider);
    final packsAsync = ref.watch(packsCatalogProvider);
    final themeMode = ref.watch(themeModeProvider);
    final mainStreak = HiveBoxes.streakFor(null);

    return dictAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Σφάλμα φόρτωσης: $e')),
      ),
      data: (_) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Λεξήμερα',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          actions: [
            IconButton(
              tooltip: tooltipForThemeMode(themeMode),
              onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
              icon: Icon(iconForThemeMode(themeMode)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openPlay(context, packId: ''),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            'Λ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Η λέξη της ημέρας',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🔥 Σερί $mainStreak · πάτα για παιχνίδι',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Πακέτα',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Θεματικές λέξεις · ξεχωριστό ημερήσιο · δεν επηρεάζει το κύριο σερί',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              packsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Σφάλμα πακέτων: $e'),
                data: (packs) {
                  if (packs.isEmpty) {
                    return const Text('Δεν υπάρχουν πακέτα ακόμα.');
                  }
                  return Column(
                    children: [
                      for (final pack in packs)
                        _PackCard(
                          pack: pack,
                          onTap: () => _openPlay(context, packId: pack.id),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlay(BuildContext context, {required String packId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(packId: packId),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.onTap});

  final PackMeta pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final packStreak = HiveBoxes.streakFor(pack.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Text(pack.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.titleEl,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack.answerCount} λέξεις'
                      '${packStreak > 0 ? ' · 🔥 $packStreak' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Play board for main daily (`packId == ''`) or a thematic pack.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.packId});

  final String packId;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  final _focus = FocusNode();
  bool _confettiPlaying = false;
  bool _shareVisible = false;
  Timer? _shareDelayTimer;
  bool _handledInitialFinish = false;

  static const _shareAfterTipDelay = Duration(milliseconds: 400);

  String get _scope => widget.packId;

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
    final ctrl = ref.read(gameControllerProvider(_scope).notifier);

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
    final probe = normalizeGreekWord('$chαααα'.substring(0, 5));
    if (probe == null) return;
    ctrl.onKey(probe[0]);
  }

  Future<void> _share() async {
    final state = ref.read(gameControllerProvider(_scope));
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
    _shareDelayTimer = Timer(_shareAfterTipDelay, () {
      if (!mounted) return;
      setState(() => _shareVisible = true);
    });
  }

  void _onWon({required bool celebrate}) {
    if (celebrate) {
      HapticFeedback.lightImpact();
      setState(() {
        _confettiPlaying = true;
        _shareVisible = false;
      });
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
      _scheduleShareVisible(afterTip: true);
    } else if (state.status == GameStatus.lost) {
      _shareVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider(_scope));
    final themeMode = ref.watch(themeModeProvider);
    final isPack = widget.packId.isNotEmpty;

    _syncFinishFromState(state);

    ref.listen<GameState>(gameControllerProvider(_scope), (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            duration: const Duration(seconds: 2),
          ),
        );
        ref.read(gameControllerProvider(_scope).notifier).clearMessage();
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

    // Main daily: single tip after win only. Packs use progressive panel.
    final showMainTip = !isPack &&
        state.status == GameStatus.won &&
        state.etymologyTip != null &&
        state.etymologyTip!.isNotEmpty;

    final showPackTips = isPack && state.packTips.isNotEmpty;

    final showShare = state.isFinished && _shareVisible;

    final title = isPack
        ? (state.packLabel ?? 'Πακέτο')
        : 'Λεξήμερα';

    final subtitle = isPack
        ? 'Πακέτο #${state.dayIndex + 1}'
        : 'Ημερήσιο #${state.dayIndex + 1}';

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onHardwareKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
              onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
              icon: Icon(iconForThemeMode(themeMode)),
            ),
            IconButton(
              tooltip: 'Πληροφορίες',
              onPressed: () => _showHelp(context, state),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
        body: state.status == GameStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                        if (showMainTip) TipCard(tip: state.etymologyTip!),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: GameBoard(rows: state.rows),
                          ),
                        ),
                        if (showPackTips)
                          ProgressiveTipsPanel(
                            tips: state.packTips,
                            isUnlocked: state.isPackTipUnlocked,
                            highlightTip3: state.highlightTip3OnWin ||
                                (state.gaveUp && state.isPackTipUnlocked(2)),
                            canManualReveal: state.canManualRevealTip,
                            onManualReveal: () => ref
                                .read(gameControllerProvider(_scope).notifier)
                                .revealManualTip(),
                            canUnlockAd: state.canUnlockAdTip,
                            onUnlockAd: () => ref
                                .read(gameControllerProvider(_scope).notifier)
                                .unlockAdTip(),
                            canGrantRewardedLetter: state.canGrantRewardedLetter,
                            onGrantRewardedLetter: () => ref
                                .read(gameControllerProvider(_scope).notifier)
                                .grantRewardedLetter(),
                            canGiveUp: state.canGiveUp,
                            onGiveUp: () => _confirmGiveUp(context),
                          ),
                        if (state.canAdvancePack)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FilledButton.icon(
                              onPressed: _advancePack,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Επόμενη'),
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
                                    : (isPack
                                        ? 'Κοινοποίηση αποτελέσματος'
                                        : 'Κοινοποίηση · λέξη: ${state.answer}'),
                              ),
                            ),
                          ),
                        GameKeyboard(
                          keyStates: state.keyStates,
                          onKey: (k) => ref
                              .read(gameControllerProvider(_scope).notifier)
                              .onKey(k),
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

  Future<void> _confirmGiveUp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Να αποκαλυφθεί η λέξη;'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Όχι'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Ναι'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(gameControllerProvider(_scope).notifier).giveUp();
    if (!context.mounted) return;
    await _showResignRevealModal();
  }

  /// Christos resign reveal: centered modal, word 32–40 bold, no tip clutter.
  Future<void> _showResignRevealModal() async {
    final answer = ref.read(gameControllerProvider(_scope)).answer;
    if (answer.isEmpty) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        final width = MediaQuery.sizeOf(ctx).width;
        final wordSize = (width * 0.09).clamp(32.0, 40.0);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Η λέξη ήταν',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  answer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: wordSize,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('next'),
                    child: const Text('Επόμενη'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop('close'),
                    child: const Text('Κλείσιμο'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'next') {
      _advancePack();
    }
  }

  void _advancePack() {
    _shareDelayTimer?.cancel();
    setState(() {
      _confettiPlaying = false;
      _shareVisible = false;
      _handledInitialFinish = false;
    });
    ref.read(gameControllerProvider(_scope).notifier).advancePackPuzzle();
  }

  void _showHelp(BuildContext context, GameState state) {
    final isPack = state.isPack;
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
              Text(
                isPack
                    ? 'Μάντεψε τη λέξη του πακέτου σε 6 προσπάθειες.\n'
                        'Πράσινο = σωστό γράμμα στη σωστή θέση.\n'
                        'Κίτρινο = υπάρχει στη λέξη, άλλη θέση.\n'
                        'Γκρι = δεν υπάρχει στη λέξη.\n\n'
                        'Υποδείξεις: tip1 με «Υπόδειξη» (δωρεάν, 1×/παζλ), '
                        'tip2 αυτόματα μετά από 4 αποτυχίες, '
                        'tip3 με «Ξεκλείδωσε με διαφήμιση».\n'
                        '«Γράμμα με διαφήμιση» γεμίζει 1 σωστό πράσινο γράμμα '
                        '(1×/παζλ, χωρίς να μετράει ως προσπάθεια).\n'
                        '«Παραίτηση» αποκαλύπτει τη λέξη και ξεκλειδώνει tip3.\n'
                        'Νέα λέξη κάθε μέρα από τη λίστα του πακέτου (UTC).\n'
                        'Το σερί του πακέτου είναι ξεχωριστό από το κύριο.'
                    : 'Μάντεψε τη λέξη της ημέρας σε 6 προσπάθειες.\n'
                        'Πράσινο = σωστό γράμμα στη σωστή θέση.\n'
                        'Κίτρινο = υπάρχει στη λέξη, άλλη θέση.\n'
                        'Γκρι = δεν υπάρχει στη λέξη.\n\n'
                        'Νέα λέξη κάθε μέρα (UTC).',
              ),
              const SizedBox(height: 8),
              Text(
                isPack
                    ? 'Σημερινό παζλ πακέτου: #${state.dayIndex + 1}'
                    : 'Σημερινό παζλ: #${state.dayIndex + 1}',
              ),
            ],
          ),
        );
      },
    );
  }
}
