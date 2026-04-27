import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'permission_badge.dart';

class AuroraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String pageTitle;
  final bool privileged;
  final VoidCallback? onRequestRoot;

  const AuroraAppBar({
    super.key,
    required this.pageTitle,
    required this.privileged,
    required this.onRequestRoot,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: dark ? 0.10 : 0.05),
            scheme.surface,
          ],
          stops: const [0.0, 0.55],
        ),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AuroraTokens.sp4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: AuroraTokens.dShort4,
            child: Text(
              pageTitle,
              key: ValueKey(pageTitle),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const Spacer(),
          if (!privileged && onRequestRoot != null)
            Padding(
              padding: const EdgeInsets.only(right: AuroraTokens.sp2),
              child: TextButton.icon(
                onPressed: onRequestRoot,
                icon: const Icon(CupertinoIcons.lock_fill, size: 12),
                label: const Text('Grant admin'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          PermissionBadge(granted: privileged),
        ],
      ),
    );
  }
}
