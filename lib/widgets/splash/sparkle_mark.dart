import 'package:flutter/material.dart';

/// The Sweep brand mark — a 4-point sparkle with two smaller accent stars,
/// rendered into a 100×100 logical canvas and scaled to [size].
class SparkleMark extends StatelessWidget {
  final double size;
  const SparkleMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _SparkleMarkPainter(),
    );
  }
}

class _SparkleMarkPainter extends CustomPainter {
  const _SparkleMarkPainter();

  static const _seed = Color(0xFF5B43D6);
  static const _seedLight = Color(0xFFA89AFA);
  static const _highlight = Color(0xFFE3DDFF);

  @override
  void paint(Canvas canvas, Size size) {
    // We model everything against a 100×100 viewbox.
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    final center = const Offset(50, 50);

    // Halo (radial glow behind the mark).
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC5BCFF).withValues(alpha: 0.9 * 0.5),
          const Color(0xFFC5BCFF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 48));
    canvas.drawCircle(center, 48, glowPaint);

    // Main 4-point sparkle.
    final mainPath = Path()
      ..moveTo(50, 8)
      ..lineTo(56, 44)
      ..lineTo(92, 50)
      ..lineTo(56, 56)
      ..lineTo(50, 92)
      ..lineTo(44, 56)
      ..lineTo(8, 50)
      ..lineTo(44, 44)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_highlight, _seedLight, _seed],
        stops: [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawPath(mainPath, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    canvas.drawPath(mainPath, strokePaint);

    // Accent stars.
    final accentPaint = Paint()..color = _highlight.withValues(alpha: 0.85);
    final accentPath = Path()
      ..moveTo(82, 22)
      ..lineTo(84, 30)
      ..lineTo(92, 32)
      ..lineTo(84, 34)
      ..lineTo(82, 42)
      ..lineTo(80, 34)
      ..lineTo(72, 32)
      ..lineTo(80, 30)
      ..close();
    canvas.drawPath(accentPath, accentPaint);

    final accentSmall = Paint()..color = _highlight.withValues(alpha: 0.65);
    final smallPath = Path()
      ..moveTo(22, 70)
      ..lineTo(23.5, 76)
      ..lineTo(30, 77.5)
      ..lineTo(23.5, 79)
      ..lineTo(22, 85)
      ..lineTo(20.5, 79)
      ..lineTo(14, 77.5)
      ..lineTo(20.5, 76)
      ..close();
    canvas.drawPath(smallPath, accentSmall);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkleMarkPainter oldDelegate) => false;
}
