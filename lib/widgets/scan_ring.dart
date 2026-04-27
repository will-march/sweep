import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Conic-gradient ring matching the design's `.hero-card .ring`.
/// Outer ring is a level-tinted arc; inner disk is the surface fill.
class ScanRing extends StatelessWidget {
  final double progress; // 0..1
  final Color trackColor;
  final Color fillColor;
  final Color innerColor;
  final String centerLabel;
  final String? centerSublabel;
  final double size;

  const ScanRing({
    super.key,
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.innerColor,
    required this.centerLabel,
    this.centerSublabel,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          fill: fillColor,
          track: trackColor,
        ),
        child: Center(
          child: Container(
            width: size - 30,
            height: size - 30,
            decoration: BoxDecoration(
              color: innerColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                      height: 1.0,
                    ),
                  ),
                  if (centerSublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      centerSublabel!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color fill;
  final Color track;
  _RingPainter({
    required this.progress,
    required this.fill,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;

    paint.color = track;
    canvas.drawCircle(rect.center, size.shortestSide / 2, paint);

    if (progress <= 0) return;
    paint.color = fill;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}
