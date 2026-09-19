import 'dart:ui';

import 'package:flutter/material.dart';

/// Pack-only progressive tip stack (Christos polish):
/// compact rows · dots 8px · unlocked tips in collapsible «Υποδείξεις (n)»
/// (default collapsed after tip1) · tip1 free CTA · tip2 auto@4 fails ·
/// tip3 ad CTA · rewarded letter CTA · give-up.
class ProgressiveTipsPanel extends StatefulWidget {
  const ProgressiveTipsPanel({
    super.key,
    required this.tips,
    required this.isUnlocked,
    required this.highlightTip3,
    required this.canManualReveal,
    required this.onManualReveal,
    required this.canUnlockAd,
    required this.onUnlockAd,
    required this.canGrantRewardedLetter,
    required this.onGrantRewardedLetter,
    required this.canGiveUp,
    required this.onGiveUp,
  });

  final List<String> tips;
  final bool Function(int index) isUnlocked;
  final bool highlightTip3;
  final bool canManualReveal;
  final VoidCallback onManualReveal;
  final bool canUnlockAd;
  final VoidCallback onUnlockAd;
  final bool canGrantRewardedLetter;
  final VoidCallback onGrantRewardedLetter;
  final bool canGiveUp;
  final VoidCallback onGiveUp;

  @override
  State<ProgressiveTipsPanel> createState() => _ProgressiveTipsPanelState();
}

class _ProgressiveTipsPanelState extends State<ProgressiveTipsPanel> {
  /// Collapsible body; default collapsed once tip1 has been unlocked.
  bool _expanded = false;
  bool _hadTip1 = false;

  int get _unlockedCount {
    var n = 0;
    final count = widget.tips.length.clamp(0, 3);
    for (var i = 0; i < count; i++) {
      if (widget.isUnlocked(i)) n++;
    }
    return n;
  }

  @override
  void initState() {
    super.initState();
    _hadTip1 = widget.tips.isNotEmpty && widget.isUnlocked(0);
    // After tip1: stay collapsed by default (no tip wall).
    _expanded = false;
  }

  @override
  void didUpdateWidget(covariant ProgressiveTipsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tip1Now =
        widget.tips.isNotEmpty && widget.isUnlocked(0);
    // First live unlock of tip1: briefly expand so the player sees it.
    if (!_hadTip1 && tip1Now) {
      _hadTip1 = true;
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tips.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final count = widget.tips.length.clamp(1, 3);
    final unlocked = _unlockedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Υπόδειξη',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
              ),
              const Spacer(),
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _TipDot(
                  unlocked: widget.isUnlocked(i),
                  highlight:
                      widget.highlightTip3 && i == 2 && widget.isUnlocked(i),
                  showPlay: i == 2 && !widget.isUnlocked(i),
                ),
              ],
            ],
          ),
          if (widget.canManualReveal ||
              widget.canUnlockAd ||
              widget.canGrantRewardedLetter) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (widget.canManualReveal)
                  TextButton.icon(
                    onPressed: widget.onManualReveal,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Υπόδειξη'),
                  ),
                if (widget.canUnlockAd)
                  TextButton.icon(
                    onPressed: widget.onUnlockAd,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Ξεκλείδωσε με διαφήμιση'),
                  ),
                if (widget.canGrantRewardedLetter)
                  TextButton.icon(
                    onPressed: widget.onGrantRewardedLetter,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Γράμμα με διαφήμιση'),
                  ),
              ],
            ),
          ],
          if (widget.canGiveUp) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: widget.onGiveUp,
                style: TextButton.styleFrom(
                  foregroundColor:
                      scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: const Text('Παραίτηση'),
              ),
            ),
          ],
          if (unlocked > 0) ...[
            const SizedBox(height: 4),
            Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Υποδείξεις ($unlocked)',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              ..._unlockedTipRows(count),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _unlockedTipRows(int count) {
    final rows = <Widget>[];
    for (var i = 0; i < count; i++) {
      if (!widget.isUnlocked(i)) continue;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(
        _TipRow(
          tip: widget.tips[i],
          unlocked: true,
          highlight: widget.highlightTip3 && i == 2,
          showPlayIcon: false,
        ),
      );
    }
    return rows;
  }
}

class _TipDot extends StatelessWidget {
  const _TipDot({
    required this.unlocked,
    required this.highlight,
    this.showPlay = false,
  });

  final bool unlocked;
  final bool highlight;
  final bool showPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (showPlay) {
      return Icon(
        Icons.play_circle_outline,
        size: 14,
        color: scheme.outline,
      );
    }
    final color = !unlocked
        ? scheme.outlineVariant
        : (highlight ? scheme.tertiary : scheme.primary);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _TipRow extends StatefulWidget {
  const _TipRow({
    required this.tip,
    required this.unlocked,
    required this.highlight,
    this.showPlayIcon = false,
  });

  final String tip;
  final bool unlocked;
  final bool highlight;
  final bool showPlayIcon;

  @override
  State<_TipRow> createState() => _TipRowState();
}

class _TipRowState extends State<_TipRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _wasUnlocked = false;

  static const _duration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _wasUnlocked = widget.unlocked;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.unlocked ? 1 : 0,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant _TipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasUnlocked && widget.unlocked) {
      _wasUnlocked = true;
      _controller.forward(from: 0);
    } else if (widget.unlocked && _controller.value < 1) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.highlight
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final fg = widget.highlight
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 48),
      child: Card(
        margin: EdgeInsets.zero,
        color: bg,
        child: Padding(
          // Christos: padding 8 vertical / 12 horizontal
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.showPlayIcon) ...[
                Icon(
                  Icons.play_circle_outline,
                  size: 18,
                  color: fg.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.unlocked ? widget.tip : '• • • • • • • • • •',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fg,
                        height: 1.2,
                        fontWeight: widget.highlight
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.unlocked) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
          child: Opacity(opacity: 0.55, child: card),
        ),
      );
    }

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: card),
    );
  }
}
