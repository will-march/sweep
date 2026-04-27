import 'package:flutter/material.dart';

import '../widgets/splash/aurora_backdrop.dart';
import '../widgets/splash/brand_block.dart';
import '../widgets/splash/cta_block.dart';
import '../widgets/splash/phase_indicator.dart';
import '../widgets/splash/spark_particles.dart';
import '../widgets/splash/step_cards.dart';

/// Animated first-launch intro for iMaculate. Storyboard:
///   0.0–1.6s · BOOT     — backdrop fades in, sparks spiral into mark
///   0.6–3.0s · BRAND    — mark blooms, wordmark types in, tagline fades
///   3.0–4.4s            — brand shrinks to top header
///   3.2–6.4s · STEPS    — Scan / Clean / Enjoy cards stagger in
///   6.0–6.6s            — cards consolidate (scale + blur)
///   6.6–8.4s · READY    — "Ready when you are." headline + CTA appears
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 8400);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF08060F),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Map controller [0..1] to seconds in the storyboard.
          final t = _controller.value * (_duration.inMilliseconds / 1000.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              AuroraBackdrop(t: t),
              SparkParticles(t: t),
              BrandBlock(t: t),
              BrandSmall(t: t),
              StepCards(t: t),
              CtaBlock(t: t, onStart: widget.onComplete),
              PhaseIndicator(t: t),
              const ChromeFooter(),
              // Skip affordance — always available, top-left.
              Positioned(
                top: 28,
                left: 36,
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0x99FFFFFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'SF Mono',
                      fontFamilyFallback: ['Menlo', 'monospace'],
                      fontSize: 10,
                      letterSpacing: 2.0,
                    ),
                  ),
                  child: const Text('SKIP →'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
