import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/splash_animation.dart';

const _seed = Color(0xFF5B43D6);
const _seedLavender = Color(0xFFC5BCFF);
const _scrub = Color(0xFF1BA864);

/// Rotating multi-blob aurora gradient with a vignette base. Subtle grain
/// shimmer is approximated with a soft animated noise layer.
class AuroraBackdrop extends StatelessWidget {
  /// Global animation time in seconds.
  final double t;
  const AuroraBackdrop({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final fadeIn = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 1.2,
      ease: easeOutCubic,
    )(t);
    final finaleBoost = animate(
      from: 0,
      to: 1,
      start: 6.6,
      end: 8.0,
      ease: easeOutCubic,
    )(t);
    final a = (t * 8) * math.pi / 180;
    final b = (t * 12 + 90) * math.pi / 180;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF08060F)),
        // Vignette base.
        Opacity(
          opacity: fadeIn,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.1),
                radius: 0.9,
                colors: [
                  Color(0xFF1A1230),
                  Color(0xFF0A0714),
                  Color(0xFF050309),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // Aurora blob 1 — purple seed, drifting top-left.
        _Blob(
          left: 0.2,
          top: 0.2,
          diameter: 800,
          color: _seed,
          opacity: 0.35 * fadeIn + 0.25 * finaleBoost,
          dx: math.cos(a) * 40,
          dy: math.sin(a) * 40,
          blurSigma: 80,
        ),
        // Aurora blob 2 — lavender, drifting top-right.
        _Blob(
          right: 0.15,
          top: 0.3,
          diameter: 700,
          color: _seedLavender,
          opacity: 0.25 * fadeIn + 0.2 * finaleBoost,
          dx: math.cos(b) * 30,
          dy: math.sin(b) * 30,
          blurSigma: 90,
        ),
        // Aurora blob 3 — emerald, only blooms during the finale.
        if (finaleBoost > 0)
          _Blob(
            center: true,
            bottom: 0.1,
            diameter: 600,
            color: _scrub,
            opacity: 0.18 * finaleBoost,
            dx: 0,
            dy: 0,
            blurSigma: 100,
          ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final bool center;
  final double diameter;
  final Color color;
  final double opacity;
  final double dx;
  final double dy;
  final double blurSigma;
  const _Blob({
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.center = false,
    required this.diameter,
    required this.color,
    required this.opacity,
    required this.dx,
    required this.dy,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) {
          final x = center
              ? (c.maxWidth - diameter) / 2 + dx
              : left != null
                  ? c.maxWidth * left! + dx
                  : c.maxWidth - c.maxWidth * right! - diameter + dx;
          final y = top != null
              ? c.maxHeight * top! + dy
              : c.maxHeight - c.maxHeight * bottom! - diameter + dy;
          return Stack(
            children: [
              Positioned(
                left: x,
                top: y,
                width: diameter,
                height: diameter,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
