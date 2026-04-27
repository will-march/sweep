import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/splash_animation.dart';
import 'sparkle_mark.dart';

const _seed = Color(0xFF5B43D6);
const _seedLight = Color(0xFF8E7DF0);

class CtaBlock extends StatelessWidget {
  final double t;
  final VoidCallback onStart;
  const CtaBlock({super.key, required this.t, required this.onStart});

  static const _start = 6.6;

  @override
  Widget build(BuildContext context) {
    if (t < _start) return const SizedBox.shrink();
    final localTime = t - _start;
    final enter = animate(
      from: 0,
      to: 1,
      start: 0,
      end: 0.8,
      ease: easeOutBack,
    )(localTime);
    final idle = math.sin(localTime * 1.6) * 0.02;
    final shimmer = (localTime * 0.8) % 1;

    return Center(
      child: Transform.translate(
        offset: Offset(0, (1 - enter) * 40),
        child: Opacity(
          opacity: enter.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: enter * (1 + idle),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SparkleMark(size: 64),
                    SizedBox(width: 18),
                    Text(
                      'Ready when you are.',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1.7,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _StartButton(shimmer: shimmer, onTap: onStart),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatefulWidget {
  final double shimmer;
  final VoidCallback onTap;
  const _StartButton({required this.shimmer, required this.onTap});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment(-1, -1),
              end: Alignment(1, 1),
              colors: [_seed, _seedLight],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B43D6).withValues(alpha: 0.5),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: _hover ? 0.45 : 0.3),
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Start scanning',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.white),
                  ],
                ),
                // Shimmer sweep, masked to the button bounds.
                Positioned(
                  left: -60 + widget.shimmer * 260,
                  top: -10,
                  bottom: -10,
                  width: 80,
                  child: Transform(
                    transform: Matrix4.skewX(-0.32),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
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
