import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/splash_animation.dart';

/// 18 particles that start far out on a circle and spiral inward over the
/// first 1.6s, blooming at the centre into the Sweep mark.
class SparkParticles extends StatelessWidget {
  final double t;
  const SparkParticles({super.key, required this.t});

  static const _phaseStart = 0.0;
  static const _phaseEnd = 1.6;
  static const _count = 18;

  @override
  Widget build(BuildContext context) {
    if (t < _phaseStart || t > _phaseEnd) return const SizedBox.shrink();
    final localTime = t - _phaseStart;

    return CustomPaint(
      painter: _SparkPainter(localTime: localTime),
      child: const SizedBox.expand(),
    );
  }
}

class _Particle {
  final double angle;
  final double delay;
  final double radius;
  final double size;
  const _Particle(this.angle, this.delay, this.radius, this.size);
}

class _SparkPainter extends CustomPainter {
  final double localTime;
  _SparkPainter({required this.localTime});

  static final _particles = List.generate(SparkParticles._count, (i) {
    final angle = (i / SparkParticles._count) * math.pi * 2 + (i % 3) * 0.4;
    final delay = (i % 6) * 0.06;
    final radius = 280 + (i % 4) * 60;
    final size = 2 + (i % 3).toDouble();
    return _Particle(angle, delay, radius.toDouble(), size);
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = canvasSize.center(Offset.zero);

    for (final p in _particles) {
      final lt = math.max(0.0, localTime - p.delay);
      final phase = clampD(lt / 1.0, 0, 1);
      final eased = easeOutCubic(phase);

      final x = math.cos(p.angle) * p.radius * (1 - eased);
      final y = math.sin(p.angle) * p.radius * (1 - eased);
      final opacity = phase < 0.85 ? phase : (1 - (phase - 0.85) / 0.15);

      // Glow under the particle.
      final glow = Paint()
        ..color = const Color(0xFFC5BCFF).withValues(alpha: opacity * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + p.size * 4);
      canvas.drawCircle(center + Offset(x, y), p.size * 2, glow);

      // The particle dot itself.
      final dot = Paint()
        ..color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(center + Offset(x, y), p.size, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.localTime != localTime;
}
