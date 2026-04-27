import 'package:flutter/material.dart';

import '../../utils/splash_animation.dart';

const _seedLight = Color(0xFF8E7DF0);

class PhaseIndicator extends StatelessWidget {
  final double t;
  const PhaseIndicator({super.key, required this.t});

  static const _phases = <(String, double)>[
    ('BOOT', 0.0),
    ('STEPS', 3.2),
    ('READY', 6.6),
  ];

  static const _start = 1.5;

  @override
  Widget build(BuildContext context) {
    if (t < _start) return const SizedBox.shrink();
    final localTime = t - _start;
    final fade = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 0.6,
      ease: easeOutCubic,
    )(localTime);

    var active = 0;
    for (var i = 0; i < _phases.length; i++) {
      if (t >= _phases[i].$2) active = i;
    }

    return Positioned(
      top: 32,
      right: 36,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _phases.length; i++) ...[
              _Dot(label: _phases[i].$1, active: i == active),
              if (i < _phases.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: Color(0x4DFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final String label;
  final bool active;
  const _Dot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _seedLight : const Color(0x40FFFFFF),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: _seedLight,
                      blurRadius: 12,
                    ),
                  ]
                : const [],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Mono',
            fontFamilyFallback: const ['Menlo', 'monospace'],
            fontSize: 10,
            letterSpacing: 2.0,
            color: active ? Colors.white : const Color(0x73FFFFFF),
          ),
        ),
      ],
    );
  }
}

class ChromeFooter extends StatelessWidget {
  const ChromeFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      bottom: 28,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'IMACULATE · v1.0 · MACOS 14+',
          style: TextStyle(
            fontFamily: 'SF Mono',
            fontFamilyFallback: ['Menlo', 'monospace'],
            fontSize: 10,
            letterSpacing: 2.4,
            color: Color(0x4DFFFFFF),
          ),
        ),
      ),
    );
  }
}
