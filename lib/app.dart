import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/tour_screen.dart';
import 'services/first_launch_service.dart';
import 'services/menu_bar_channel.dart';
import 'theme/app_theme.dart';

/// First-launch gate. The user steps through:
///   1. Splash      — the 1-2-3 scan/clean/enjoy animation.
///   2. Tour        — the multi-page guided product tour.
///   3. Walkthrough — live coachmark overlay on top of HomeShell.
///   4. HomeShell   — the regular app.
/// Each step writes a marker to ~/Library/Application Support/Sweep
/// so subsequent launches skip the gate.
enum _LaunchStage { unknown, splash, tour, walkthrough, home }

class SweepApp extends StatefulWidget {
  const SweepApp({super.key});

  @override
  State<SweepApp> createState() => _SweepAppState();
}

class _SweepAppState extends State<SweepApp> {
  final _firstLaunch = FirstLaunchService();
  _LaunchStage _stage = _LaunchStage.unknown;

  @override
  void initState() {
    super.initState();
    _resolveStage();
    // Bind the menu bar channel once — the Swift NSStatusItem stays
    // around for the lifetime of the window and routes user picks
    // through this handler.
    MenuBarChannel.install();
  }

  Future<void> _resolveStage() async {
    // Wipe markers if the user / QA launched with
    // SWEEP_RESET_ONBOARDING=1. Done before reading any state so
    // the gate behaves identically to a brand-new install.
    await _firstLaunch.maybeReset();
    final intro = await _firstLaunch.hasSeenIntro();
    final tour = await _firstLaunch.hasSeenTour();
    final walkthrough = await _firstLaunch.hasSeenWalkthrough();
    if (!mounted) return;
    setState(() {
      _stage = !intro
          ? _LaunchStage.splash
          : !tour
              ? _LaunchStage.tour
              : !walkthrough
                  ? _LaunchStage.walkthrough
                  : _LaunchStage.home;
    });
  }

  Future<void> _completeSplash() async {
    await _firstLaunch.markIntroSeen();
    if (!mounted) return;
    setState(() => _stage = _LaunchStage.tour);
  }

  Future<void> _completeTour() async {
    await _firstLaunch.markTourSeen();
    if (!mounted) return;
    setState(() => _stage = _LaunchStage.walkthrough);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sweep',
      debugShowCheckedModeBanner: false,
      // Global messenger so handlers outside the widget tree (the menu
      // bar's MethodChannel) can showSnackBar.
      scaffoldMessengerKey: MenuBarChannel.messengerKey,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: switch (_stage) {
        // While we read marker files, paint the splash backdrop so the
        // window doesn't flash white.
        _LaunchStage.unknown => const ColoredBox(color: Color(0xFF08060F)),
        _LaunchStage.splash => SplashScreen(onComplete: _completeSplash),
        _LaunchStage.tour => TourScreen(onComplete: _completeTour),
        // The walkthrough renders the real HomeShell with an active
        // coachmark overlay; HomeShell's own listener writes the
        // walkthrough_seen marker once the user finishes or skips.
        _LaunchStage.walkthrough => const HomeShell(startWalkthrough: true),
        _LaunchStage.home => const HomeShell(),
      },
    );
  }
}
