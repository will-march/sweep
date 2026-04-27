import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class StatItem {
  final String label;
  final String value;
  final Color? valueColor;
  const StatItem({required this.label, required this.value, this.valueColor});
}

class AppStatsRow extends StatelessWidget {
  final List<StatItem> items;
  const AppStatsRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: _StatCard(item: items[i])),
          if (i != items.length - 1) const SizedBox(width: AuroraTokens.sp3),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuroraTokens.sp4,
        vertical: AuroraTokens.sp3,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: item.valueColor ?? scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
