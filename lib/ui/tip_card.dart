import 'package:flutter/material.dart';

/// Etymology tip; hidden when empty. On appear: slide-up 280ms + scale 0.96→1.
class TipCard extends StatefulWidget {
  const TipCard({super.key, required this.tip});

  final String tip;

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  static const _duration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.tip.trim().isNotEmpty) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant TipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasEmpty = oldWidget.tip.trim().isEmpty;
    final isEmpty = widget.tip.trim().isEmpty;
    if (wasEmpty && !isEmpty) {
      _controller.forward(from: 0);
    } else if (!wasEmpty && isEmpty) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tip.trim().isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.tip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
