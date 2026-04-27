import 'package:flutter/material.dart';

import '../models/cleaning_level.dart';
import '../theme/level_palette.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';
import 'scan_ring.dart';

/// Aurora hero card — per-level gradient surface, eyebrow, big reclaim
/// figure with " GB" suffix, and a conic scan ring on the right.
class HeroSizeCard extends StatelessWidget {
  final CleaningLevel level;
  final int totalBytes;
  final int itemCount;
  final bool isLoading;
  final double scanProgress; // 0..1

  const HeroSizeCard({
    super.key,
    required this.level,
    required this.totalBytes,
    required this.itemCount,
    required this.isLoading,
    required this.scanProgress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final palette = levelPalette(level);

    final gradientColors = dark
        ? [
            palette.t50.withValues(alpha: 0.22),
            palette.t50.withValues(alpha: 0.06),
          ]
        : [palette.t95, palette.t90];
    final fg = dark ? palette.t80 : palette.t30;

    final formatted = formatBytes(totalBytes);
    final spaceIdx = formatted.lastIndexOf(' ');
    final value =
        spaceIdx == -1 ? formatted : formatted.substring(0, spaceIdx);
    final unit =
        spaceIdx == -1 ? '' : formatted.substring(spaceIdx + 1);

    return AnimatedContainer(
      duration: AuroraTokens.dShort4,
      curve: AuroraTokens.standardEasing,
      padding: const EdgeInsets.all(AuroraTokens.sp5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuroraTokens.shapeLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RECLAIMABLE NOW · ${level.title.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: AuroraTokens.dShort4,
                  child: Row(
                    key: ValueKey('$isLoading-$totalBytes'),
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isLoading ? '—' : value,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.5,
                          height: 1.0,
                          color: fg,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (unit.isNotEmpty && !isLoading) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: fg.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLoading
                      ? 'Calculating sizes…'
                      : itemCount == 0
                          ? 'No matching caches found.'
                          : 'across $itemCount cache ${itemCount == 1 ? "directory" : "directories"} — '
                              '${level.title.toLowerCase()}.',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuroraTokens.sp5),
          ScanRing(
            progress: isLoading ? 0.0 : scanProgress,
            fillColor: palette.accent(brightness),
            trackColor: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.45),
            innerColor: scheme.surface,
            centerLabel: '${(scanProgress * 100).round()}%',
            centerSublabel: isLoading ? 'scanning' : 'scanned',
          ),
        ],
      ),
    );
  }
}
