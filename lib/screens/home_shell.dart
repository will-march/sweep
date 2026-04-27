import 'package:flutter/material.dart';

import '../models/cleaning_level.dart';
import '../models/nav_selection.dart';
import '../services/first_launch_service.dart';
import '../services/permission_service.dart';
import '../services/walkthrough_controller.dart';
import '../widgets/aurora_app_bar.dart';
import '../widgets/aurora_sidebar.dart';
import '../widgets/walkthrough_overlay.dart';
import 'cleaner_screen.dart';
import 'exclusions_screen.dart';
import 'history_screen.dart';
import 'schedule_screen.dart';
import 'tree_map_screen.dart';
import 'uninstaller_screen.dart';

class HomeShell extends StatefulWidget {
  /// True on the very first run after the splash + intro tour. When
  /// set, HomeShell auto-starts the live coachmark walkthrough.
  final bool startWalkthrough;
  const HomeShell({super.key, this.startWalkthrough = false});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  NavSelection _selection = const CleaningNav(CleaningLevel.lightScrub);
  bool _privileged = false;
  final _permission = PermissionService();
  final _firstLaunch = FirstLaunchService();
  late final WalkthroughController _walkthrough = WalkthroughController()
    ..onNavigationRequest =
        (s) => mounted ? setState(() => _selection = s) : null;

  @override
  void initState() {
    super.initState();
    _askForPermission();
    if (widget.startWalkthrough) {
      // Defer one frame so descendants have time to mount their
      // walkthrough keys before the overlay tries to read them.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _walkthrough.start();
      });
    }
    _walkthrough.addListener(_persistWalkthroughCompletion);
  }

  @override
  void dispose() {
    _walkthrough.removeListener(_persistWalkthroughCompletion);
    _walkthrough.dispose();
    super.dispose();
  }

  Future<void> _persistWalkthroughCompletion() async {
    // Once the walkthrough is no longer active *and* we'd previously
    // started it, remember that the user has seen it.
    if (!_walkthrough.active && widget.startWalkthrough) {
      await _firstLaunch.markWalkthroughSeen();
    }
  }

  Future<void> _askForPermission() async {
    final ok = await _permission.requestRoot();
    if (!mounted) return;
    if (ok) setState(() => _privileged = true);
  }

  Widget _content() {
    switch (_selection) {
      case CleaningNav(level: final l):
        return CleanerScreen(level: l, privileged: _privileged);
      case UsageNav(view: UsageView.treeMap):
        return TreeMapScreen(privileged: _privileged);
      case ToolNav(view: ToolView.history):
        return const HistoryScreen();
      case ToolNav(view: ToolView.exclusions):
        return const ExclusionsScreen();
      case ToolNav(view: ToolView.schedule):
        return ScheduleScreen(privileged: _privileged);
      case ToolNav(view: ToolView.uninstaller):
        return const UninstallerScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Walkthrough(
      controller: _walkthrough,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            // Ambient brand-purple radial wash behind the entire app body.
            // Subtle in light mode (so cards stay legible) and slightly
            // stronger in dark mode where it reads as atmosphere.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -0.9),
                      radius: 1.4,
                      colors: [
                        scheme.primary.withValues(alpha: dark ? 0.10 : 0.06),
                        scheme.surface.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuroraSidebar(
                  selection: _selection,
                  onSelect: (s) => setState(() => _selection = s),
                ),
                Expanded(
                  child: Column(
                    children: [
                      AuroraAppBar(
                        pageTitle: _selection.pageTitle,
                        privileged: _privileged,
                        onRequestRoot:
                            _privileged ? null : _askForPermission,
                      ),
                      Expanded(child: _content()),
                    ],
                  ),
                ),
              ],
            ),
            // Coachmark overlay on top of everything. Listens to the
            // controller and only paints while [active] is true.
            Positioned.fill(
              child: WalkthroughOverlay(controller: _walkthrough),
            ),
          ],
        ),
      ),
    );
  }
}
