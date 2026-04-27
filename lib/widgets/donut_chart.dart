import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class DonutSlice {
  final String label;
  final int value;
  final Color color;
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Animated donut chart. Slices are drawn with 2-pixel gaps for clarity, the
/// chart sweeps in from 0 → 1 on data change, and the centre carries a primary
/// label and an optional sublabel.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final String centerLabel;
  final String? centerSublabel;
  final double diameter;
  final double thickness;

  const DonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.centerSublabel,
    this.diameter = 280,
    this.thickness = 36,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AuroraTokens.dLong1,
        curve: AuroraTokens.standardEasing,
        builder: (context, t, _) {
          return CustomPaint(
            painter: _DonutPainter(
              slices: slices,
              total: total,
              progress: t,
              thickness: thickness,
              trackColor: scheme.surfaceContainerHigh,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (centerSublabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        centerSublabel!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final int total;
  final double progress;
  final double thickness;
  final Color trackColor;

  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.thickness,
    required this.trackColor,
  });

  static const _gap = 0.022; // radians between slices

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - thickness / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, track);

    if (total <= 0 || slices.isEmpty) return;

    final sweepAvail = 2 * math.pi - _gap * slices.length;
    var start = -math.pi / 2 + _gap / 2;

    for (final s in slices) {
      final fraction = s.value / total;
      final sweep = sweepAvail * fraction * progress;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = thickness
        ..isAntiAlias = true;

      if (sweep > 0.0001) {
        canvas.drawArc(rect, start, sweep, false, paint);
      }
      start += sweepAvail * fraction + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices ||
      old.total != total ||
      old.progress != progress ||
      old.thickness != thickness ||
      old.trackColor != trackColor;
}
