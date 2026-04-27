import 'package:flutter/material.dart';

import '../models/cache_target.dart';
import '../theme/level_palette.dart';
import '../theme/tokens.dart';

/// Aurora risk chip — leading 3×12 bar + uppercase label, level-tinted.
class RiskChip extends StatelessWidget {
  final RiskLevel risk;
  const RiskChip({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final palette = riskPalette(risk);
    final dark = brightness == Brightness.dark;
    final bg = dark
        ? palette.t80.withValues(alpha: 0.14)
        : palette.t95;
    final fg = dark ? palette.t80 : palette.t30;
    final bar = dark ? palette.t80 : palette.t40;

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuroraTokens.shapeXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            risk.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
