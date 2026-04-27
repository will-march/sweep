import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/cleaning_level.dart';
import '../models/nav_selection.dart';
import '../theme/level_palette.dart';
import '../theme/tokens.dart';

class AuroraSidebar extends StatelessWidget {
  final NavSelection selection;
  final ValueChanged<NavSelection> onSelect;
  const AuroraSidebar({
    super.key,
    required this.selection,
    required this.onSelect,
  });

  static const width = 220.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant),
        ),
        // Brand purple wash anchored at the top, fading down. Stronger in
        // dark mode to keep the chrome from washing out.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: const Alignment(0, 0.6),
          colors: [
            scheme.primary.withValues(alpha: dark ? 0.18 : 0.10),
            scheme.surfaceContainerLow,
          ],
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title-bar gutter so the brand sits below the macOS traffic
            // lights (the window has fullSizeContentView enabled).
            const SizedBox(height: 38),
            const _Brand(),
            const SizedBox(height: AuroraTokens.sp4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuroraTokens.sp2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionHeader('Cleaning'),
                    for (final l in CleaningLevel.values)
                      _NavRow(
                        icon: l.icon,
                        label: l.title,
                        accent: levelPalette(l)
                            .accent(Theme.of(context).brightness),
                        active: selection is CleaningNav &&
                            (selection as CleaningNav).level == l,
                        onTap: () => onSelect(CleaningNav(l)),
                      ),
                    const SizedBox(height: AuroraTokens.sp4),
                    const _SectionHeader('Usage'),
                    _NavRow(
                      icon: CupertinoIcons.chart_pie_fill,
                      label: 'Tree Map',
                      accent: scheme.primary,
                      active: selection is UsageNav &&
                          (selection as UsageNav).view == UsageView.treeMap,
                      onTap: () => onSelect(const UsageNav(UsageView.treeMap)),
                    ),
                    const SizedBox(height: AuroraTokens.sp4),
                    const _SectionHeader('Tools'),
                    _NavRow(
                      icon: CupertinoIcons.clock_fill,
                      label: 'History',
                      accent: scheme.primary,
                      active: selection is ToolNav &&
                          (selection as ToolNav).view == ToolView.history,
                      onTap: () =>
                          onSelect(const ToolNav(ToolView.history)),
                    ),
                    _NavRow(
                      icon: CupertinoIcons.shield_fill,
                      label: 'Exclusions',
                      accent: scheme.primary,
                      active: selection is ToolNav &&
                          (selection as ToolNav).view == ToolView.exclusions,
                      onTap: () =>
                          onSelect(const ToolNav(ToolView.exclusions)),
                    ),
                    _NavRow(
                      icon: CupertinoIcons.calendar,
                      label: 'Schedule',
                      accent: scheme.primary,
                      active: selection is ToolNav &&
                          (selection as ToolNav).view == ToolView.schedule,
                      onTap: () =>
                          onSelect(const ToolNav(ToolView.schedule)),
                    ),
                    _NavRow(
                      icon: CupertinoIcons.app_badge_fill,
                      label: 'Uninstaller',
                      accent: scheme.primary,
                      active: selection is ToolNav &&
                          (selection as ToolNav).view == ToolView.uninstaller,
                      onTap: () =>
                          onSelect(const ToolNav(ToolView.uninstaller)),
                    ),
                  ],
                ),
              ),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AuroraTokens.sp4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Mirrors the splash mark gradient: highlight → lavender → seed.
                colors: [
                  Color(0xFFE3DDFF),
                  Color(0xFFA89AFA),
                  Color(0xFF5B43D6),
                ],
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B43D6).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: AuroraTokens.sp2),
          Text(
            'iMaculate',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp3,
        AuroraTokens.sp3,
        AuroraTokens.sp3,
        AuroraTokens.sp1,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool active;
  final VoidCallback onTap;
  const _NavRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.active ? scheme.onSurface : scheme.onSurfaceVariant;
    final bg = widget.active
        ? scheme.surfaceContainerHighest
        : _hover
            ? scheme.surfaceContainer
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AuroraTokens.dShort2,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AuroraTokens.shapeSm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AuroraTokens.sp3,
            vertical: AuroraTokens.sp2,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.active ? widget.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AuroraTokens.sp2),
              Icon(widget.icon, size: 15, color: widget.accent),
              const SizedBox(width: AuroraTokens.sp2),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        widget.active ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp4,
        AuroraTokens.sp3,
        AuroraTokens.sp4,
        AuroraTokens.sp4,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: AuroraTokens.sp2),
          Text(
            'Aurora · v1',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.3,
              fontFamily: 'SF Mono',
              fontFamilyFallback: const ['Menlo', 'monospace'],
            ),
          ),
        ],
      ),
    );
  }
}
