import 'dart:math' as math;

import 'package:flutter/material.dart';

const _seed = Color(0xFF5B43D6);
const _seedLight = Color(0xFF8E7DF0);
const _scrub = Color(0xFF1BA864);

class ScanIcon extends StatelessWidget {
  final double progress;
  const ScanIcon({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(80),
      painter: _ScanPainter(progress: progress),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double progress;
  _ScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // Folder body.
    final folderPath = Path()
      ..moveTo(22, 32)
      ..lineTo(42, 32)
      ..lineTo(48, 38)
      ..lineTo(78, 38)
      ..lineTo(78, 72)
      ..lineTo(22, 72)
      ..close();

    final folderFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawPath(folderPath, folderFill);

    final folderStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(folderPath, folderStroke);

    // Two phased radar rings.
    final ringPaint1 = Paint()
      ..color = _scrub.withValues(alpha: (1 - progress * 0.7).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(50, 55), 6 + progress * 22, ringPaint1);

    final p2 = (progress + 0.3) % 1;
    final ringPaint2 = Paint()
      ..color = _scrub.withValues(alpha: (1 - p2) * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(const Offset(50, 55), 6 + p2 * 22, ringPaint2);

    // Sweep wedge.
    canvas.save();
    canvas.translate(50, 55);
    final sweepAngle = (-90 + progress * 360) * math.pi / 180;
    canvas.rotate(sweepAngle);
    final sweepPath = Path()
      ..moveTo(0, 0)
      ..lineTo(26, 0)
      ..arcToPoint(
        const Offset(13, -22.5),
        radius: const Radius.circular(26),
        clockwise: false,
      )
      ..close();
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _scrub.withValues(alpha: 0.0),
          _scrub.withValues(alpha: 0.8 * 0.7),
        ],
      ).createShader(const Rect.fromLTWH(0, -25, 26, 25));
    canvas.drawPath(sweepPath, sweepPaint);
    canvas.restore();

    // Centre dot.
    canvas.drawCircle(
      const Offset(50, 55),
      2.5,
      Paint()..color = _scrub,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) => old.progress != progress;
}

class CleanIcon extends StatelessWidget {
  final double progress;
  const CleanIcon({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(80),
      painter: _CleanPainter(progress: progress),
    );
  }
}

class _CleanPainter extends CustomPainter {
  final double progress;
  _CleanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // Dust particles being sucked into the centre.
    for (var i = 0; i < 14; i++) {
      final local = (progress * 1.5 + i * 0.07) % 1;
      final angle = i * 0.8 + local * math.pi * 2;
      final r = 36 * (1 - local);
      final x = 50 + math.cos(angle) * r;
      final y = 50 + math.sin(angle) * r;
      final op = local < 0.85 ? 0.85 : 0.0;
      if (op == 0) continue;
      canvas.drawCircle(
        Offset(x, y),
        1.5 + (1 - local) * 1.2,
        Paint()..color = Colors.white.withValues(alpha: op),
      );
    }

    // Swirl arms — rotate around centre.
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(progress * 2 * math.pi);
    final armPaint = Paint()
      ..color = _seedLight.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final arm1 = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(20, 0, 20, -20)
      ..quadraticBezierTo(20, -28, 12, -28);
    canvas.drawPath(arm1, armPaint);
    final arm2 = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-20, 0, -20, 20)
      ..quadraticBezierTo(-20, 28, -12, 28);
    canvas.drawPath(arm2, armPaint);
    canvas.restore();

    // Glowing core.
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, _seedLight, Color(0x005B43D6)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(
        center: const Offset(50, 50),
        radius: 14,
      ));
    canvas.drawCircle(const Offset(50, 50), 14, corePaint);
    canvas.drawCircle(const Offset(50, 50), 4, Paint()..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CleanPainter old) => old.progress != progress;
}

class EnjoyIcon extends StatelessWidget {
  final double progress;
  const EnjoyIcon({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(80),
      painter: _EnjoyPainter(progress: progress),
    );
  }
}

class _EnjoyPainter extends CustomPainter {
  final double progress;
  _EnjoyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // Outer disk fill + stroke.
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.18),
          _scrub.withValues(alpha: 0.25),
        ],
      ).createShader(Rect.fromCircle(
        center: const Offset(50, 50),
        radius: 32,
      ));
    canvas.drawCircle(const Offset(50, 50), 32, fillPaint);

    final outerStroke = Paint()
      ..color = _scrub
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(50, 50), 32, outerStroke);

    // Inner ring.
    final innerStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(const Offset(50, 50), 22, innerStroke);

    // Animated checkmark.
    final checkLen = 30.0;
    final checkProgress = math.min(1.0, progress * 1.6);
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(40, 52)
      ..lineTo(47, 60)
      ..lineTo(62, 42);
    final metric = checkPath.computeMetrics().first;
    final visible = metric.extractPath(0, checkLen * checkProgress);
    canvas.drawPath(visible, checkPaint);

    // Sparkles, breathing in size with the progress.
    final sparkleScale = 0.6 + math.sin(progress * math.pi * 2) * 0.15;
    _drawSparkle(canvas, const Offset(76, 24), sparkleScale, 0.9);
    _drawSparkle(canvas, const Offset(20, 78), sparkleScale * 0.7, 0.7);

    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Offset center, double scale, double alpha) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(0, -8)
      ..lineTo(2, -2)
      ..lineTo(8, 0)
      ..lineTo(2, 2)
      ..lineTo(0, 8)
      ..lineTo(-2, 2)
      ..lineTo(-8, 0)
      ..lineTo(-2, -2)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnjoyPainter old) => old.progress != progress;
}

const stepScrubAccent = _scrub;
const stepCleanAccent = _seed;
const stepEnjoyAccent = _scrub;
