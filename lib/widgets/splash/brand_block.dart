import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/splash_animation.dart';
import 'sparkle_mark.dart';

const _seed = Color(0xFF5B43D6);
const _seedLight = Color(0xFF8E7DF0);
const _highlight = Color(0xFFE3DDFF);

/// Centre brand: mark blooms with overshoot, idle bob, "Sweep" wordmark
/// types in (gradient on "Maculate"), tagline fades. Visible 0.6s → 3.0s.
class BrandBlock extends StatelessWidget {
  final double t;
  const BrandBlock({super.key, required this.t});

  static const _start = 0.6;
  static const _end = 3.0;

  @override
  Widget build(BuildContext context) {
    if (t < _start || t > _end) return const SizedBox.shrink();
    final localTime = t - _start;

    final bloom = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 0.7,
      ease: easeOutBack,
    )(localTime);
    final fade = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 0.6,
      ease: easeOutCubic,
    )(localTime);
    final wmShow = animate(
      from: 0,
      to: 1,
      start: 0.55,
      end: 1.2,
      ease: easeOutCubic,
    )(localTime);
    final idle = math.sin(localTime * 1.4) * 4;
    // Soft pulse after the bloom completes.
    final pulse = 1 + math.max(0, math.sin((localTime - 0.7) * 4)) * 0.025;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, idle * 0.5),
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: bloom * pulse,
                child: Container(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x8C5B43D6),
                        blurRadius: 40,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const SparkleMark(size: 140),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Opacity(
            opacity: wmShow.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - wmShow) * 14),
              child: const _Wordmark(),
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: wmShow.clamp(0.0, 1.0),
            child: const Text(
              'KEEP YOUR MAC PRISTINE.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0x8CFFFFFF),
                letterSpacing: 2.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text(
          'i',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            letterSpacing: -2.2,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment(-1, -1),
            end: Alignment(1, 1),
            colors: [_highlight, _seedLight, _seed],
            stops: [0.0, 0.5, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Maculate',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w700,
              letterSpacing: -2.2,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

/// Smaller brand: shrunk mark + wordmark anchored near the top of the stage,
/// active 3.0s → 4.4s as the steps come on.
class BrandSmall extends StatelessWidget {
  final double t;
  const BrandSmall({super.key, required this.t});

  static const _start = 3.0;
  static const _end = 8.4;

  @override
  Widget build(BuildContext context) {
    if (t < _start || t > _end) return const SizedBox.shrink();
    final localTime = t - _start;
    final enter = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 0.5,
      ease: easeOutCubic,
    )(localTime);
    final exit = animate(
      from: 0,
      to: 1,
      start: 3.5,
      end: 4.4,
      ease: easeInOutCubic,
    )(localTime);
    final opacity = (enter * (1 - exit)).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();

    final y = (1 - enter) * 30 + exit * -20;

    return Align(
      alignment: const Alignment(0, -0.85),
      child: Transform.translate(
        offset: Offset(0, y),
        child: Opacity(
          opacity: opacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SparkleMark(size: 44),
              const SizedBox(width: 14),
              const Text(
                'Sweep',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
