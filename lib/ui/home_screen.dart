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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

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
    });

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
            if (state.isFinished)
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
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ημερήσιο #${state.dayIndex + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (state.status == GameStatus.won &&
                  state.etymologyTip != null &&
                  state.etymologyTip!.isNotEmpty)
                TipCard(tip: state.etymologyTip!),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: GameBoard(rows: state.rows),
                ),
              ),
              if (state.isFinished)
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
