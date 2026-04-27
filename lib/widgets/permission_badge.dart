import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/level_palette.dart';
import '../theme/tokens.dart';

class PermissionBadge extends StatelessWidget {
  final bool granted;
  const PermissionBadge({super.key, required this.granted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final accent = granted
        ? scrubPalette.accent(brightness)
        : sandPalette.accent(brightness);
    final label = granted ? 'Root granted' : 'User mode';
    final icon = granted
        ? CupertinoIcons.lock_open_fill
        : CupertinoIcons.lock_fill;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
