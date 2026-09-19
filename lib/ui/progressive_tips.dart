import 'dart:ui';

import 'package:flutter/material.dart';

/// Pack-only progressive tip stack (Christos):
/// tip1 free CTA · tip2 auto@4 fails · tip3 ad CTA with play icon · give-up.
class ProgressiveTipsPanel extends StatelessWidget {
  const ProgressiveTipsPanel({
    super.key,
    required this.tips,
    required this.isUnlocked,
    required this.highlightTip3,
    required this.canManualReveal,
    required this.onManualReveal,
    required this.canUnlockAd,
    required this.onUnlockAd,
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
  final bool canGiveUp;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final count = tips.length.clamp(1, 3);

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
                  unlocked: isUnlocked(i),
                  highlight: highlightTip3 && i == 2 && isUnlocked(i),
                  showPlay: i == 2 && !isUnlocked(i),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _TipRow(
              tip: tips[i],
              unlocked: isUnlocked(i),
              highlight: highlightTip3 && i == 2 && isUnlocked(i),
              showPlayIcon: i == 2 && !isUnlocked(i),
            ),
          ],
          if (canManualReveal || canUnlockAd) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (canManualReveal)
                  TextButton.icon(
                    onPressed: onManualReveal,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Υπόδειξη'),
                  ),
                if (canUnlockAd)
                  TextButton.icon(
                    onPressed: onUnlockAd,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Ξεκλείδωσε με διαφήμιση'),
                  ),
              ],
            ),
          ],
          if (canGiveUp) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onGiveUp,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
      width: 10,
      height: 10,
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

    final card = Card(
      margin: EdgeInsets.zero,
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showPlayIcon) ...[
              Icon(Icons.play_circle_outline, size: 18, color: fg.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                widget.unlocked ? widget.tip : '• • • • • • • • • •',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight:
                          widget.highlight ? FontWeight.w700 : FontWeight.w500,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
