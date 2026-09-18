import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Lightweight confetti burst using [CustomPainter] — no extra packages.
/// Plays for [duration] when [playing] flips to true, then idles.
class WinConfetti extends StatefulWidget {
  const WinConfetti({
    super.key,
    required this.playing,
    this.duration = const Duration(milliseconds: 1200),
  });

  final bool playing;
  final Duration duration;

  @override
  State<WinConfetti> createState() => _WinConfettiState();
}

class _WinConfettiState extends State<WinConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Particle> _particles = const [];
  int _burstId = 0;

  static const _colors = [
    LexColors.correct,
    LexColors.present,
    Color(0xFF538D4E), // deeper green (board-adjacent)
    Color(0xFFB59F3B), // deeper yellow
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {});
        }
      });
    if (widget.playing) _startBurst();
  }

  @override
  void didUpdateWidget(covariant WinConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !oldWidget.playing) {
      _startBurst();
    }
  }

  void _startBurst() {
    final rng = math.Random(++_burstId);
    _particles = List.generate(48, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.2;
      final speed = 220 + rng.nextDouble() * 320;
      return _Particle(
        color: _colors[rng.nextInt(_colors.length)],
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 4 + rng.nextDouble() * 5,
        rotation: rng.nextDouble() * math.pi,
        spin: (rng.nextDouble() - 0.5) * 6,
        x0: 0.35 + rng.nextDouble() * 0.3,
        y0: 0.28 + rng.nextDouble() * 0.12,
      );
    });
    _controller.duration = widget.duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating && _controller.value == 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              t: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.color,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.x0,
    required this.y0,
  });

  final Color color;
  final double vx;
  final double vy;
  final double size;
  final double rotation;
  final double spin;
  final double x0;
  final double y0;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  static const _gravity = 520.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final seconds = t * 1.2;
    final fade = (1.0 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = p.x0 * size.width + p.vx * seconds;
      final y = p.y0 * size.height + p.vy * seconds + 0.5 * _gravity * seconds * seconds;
      if (x < -20 || x > size.width + 20 || y > size.height + 20) continue;

      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * seconds);
      final w = p.size;
      final h = p.size * 0.55;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1.2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.particles != particles;
}
