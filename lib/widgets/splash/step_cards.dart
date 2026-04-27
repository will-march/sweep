import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/splash_animation.dart';
import 'step_icons.dart';

class _StepDef {
  final int index;
  final double startOffset;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget Function(double progress) iconBuilder;
  const _StepDef({
    required this.index,
    required this.startOffset,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.iconBuilder,
  });
}

class StepCards extends StatelessWidget {
  final double t;
  const StepCards({super.key, required this.t});

  static const _phaseStart = 3.2;
  static const _phaseEnd = 8.4;

  static final _steps = <_StepDef>[
    _StepDef(
      index: 1,
      startOffset: 0.0,
      title: 'Scan',
      subtitle:
          'We map every cache, log, and stale build artifact across your Mac.',
      accent: stepScrubAccent,
      iconBuilder: (p) => ScanIcon(progress: p),
    ),
    _StepDef(
      index: 2,
      startOffset: 0.5,
      title: 'Clean',
      subtitle:
          'Pick a level — Light Scrub to Sandblast — and reclaim what you need.',
      accent: stepCleanAccent,
      iconBuilder: (p) => CleanIcon(progress: p),
    ),
    _StepDef(
      index: 3,
      startOffset: 1.0,
      title: 'Enjoy',
      subtitle:
          'Tens of gigabytes back. Faster builds. A pristine machine.',
      accent: stepEnjoyAccent,
      iconBuilder: (p) => EnjoyIcon(progress: p),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (t < _phaseStart || t > _phaseEnd) return const SizedBox.shrink();

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Connector(t: t),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                _StepCard(t: t, def: _steps[i]),
                if (i != _steps.length - 1) const SizedBox(width: 28),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final double t;
  const _Connector({required this.t});

  @override
  Widget build(BuildContext context) {
    if (t < 3.4 || t > 6.4) return const SizedBox.shrink();
    final localTime = t - 3.4;
    final len = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 1.0,
      ease: easeInOutCubic,
    )(localTime);
    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: 820,
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.35 * len),
                  Colors.white.withValues(alpha: 0.35 * len),
                  Colors.transparent,
                ],
                stops: [
                  0.0,
                  (len * 0.5).clamp(0.0, 0.5),
                  (1 - len * 0.5).clamp(0.5, 1.0),
                  1.0,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final double t;
  final _StepDef def;
  const _StepCard({required this.t, required this.def});

  @override
  Widget build(BuildContext context) {
    final start = 3.2 + def.startOffset;
    if (t < start) return const SizedBox(width: 240);
    final localTime = t - start;

    final enter = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 0.7,
      ease: easeOutBack,
    )(localTime);
    final exit = animate(
      from: 0,
      to: 1,
      start: 3.0,
      end: 3.6,
      ease: easeInCubic,
    )(localTime);
    final consolidate = animate(
      from: 0,
      to: 1,
      start: 2.6,
      end: 3.4,
      ease: easeInOutCubic,
    )(localTime);

    final opacity = (enter * (1 - exit * 0.7)).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox(width: 240);
    final y = (1 - enter) * 60;
    final scale = 1 - consolidate * 0.08;
    final blur = consolidate * 4;

    final iconProgress = clampD(localTime * 0.6, 0, 1);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 60,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Accent glow.
              Positioned(
                top: -40,
                right: -40,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          def.accent.withValues(alpha: 0.35),
                          def.accent.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.65],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'STEP ${def.index.toString().padLeft(2, '0')} / 03',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'SF Mono',
                      fontFamilyFallback: ['Menlo', 'monospace'],
                      letterSpacing: 2.2,
                      color: Color(0x80FFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  def.iconBuilder(iconProgress),
                  const SizedBox(height: 18),
                  Text(
                    def.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    def.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0x99FFFFFF),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (blur > 0) {
      card = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: card,
      );
    }

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, y),
        child: Transform.scale(
          scale: scale,
          child: card,
        ),
      ),
    );
  }
}
