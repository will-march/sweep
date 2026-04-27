import 'package:flutter/material.dart';

import '../models/cache_entry.dart';
import '../theme/level_palette.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';
import 'risk_chip.dart';

/// Aurora cache tile.
/// Layout: 4px accent bar | meta (name + RiskChip, mono path) | size + Delete.
class CacheTile extends StatelessWidget {
  final CacheEntry entry;
  final VoidCallback onDelete;
  const CacheTile({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final accent = riskPalette(entry.target.risk).accent(brightness);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuroraTokens.sp4,
                  AuroraTokens.sp3,
                  AuroraTokens.sp3,
                  AuroraTokens.sp3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.target.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              RiskChip(risk: entry.target.risk),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.directory.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'SF Mono',
                              fontFamilyFallback: const [
                                'JetBrains Mono',
                                'Menlo',
                                'Consolas',
                                'monospace',
                              ],
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AuroraTokens.sp4),
                    Text(
                      formatBytes(entry.sizeBytes),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: AuroraTokens.sp3),
                    SizedBox(
                      height: 26,
                      child: FilledButton(
                        onPressed: onDelete,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 26),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AuroraTokens.shapeXs),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
