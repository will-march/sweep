import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'services/first_launch_service.dart';
import 'theme/app_theme.dart';

class IMaculateApp extends StatefulWidget {
  const IMaculateApp({super.key});

  @override
  State<IMaculateApp> createState() => _IMaculateAppState();
}

class _IMaculateAppState extends State<IMaculateApp> {
  final _firstLaunch = FirstLaunchService();
  late Future<bool> _seen;

  @override
  void initState() {
    super.initState();
    _seen = _firstLaunch.hasSeenIntro();
  }

  Future<void> _completeIntro() async {
    await _firstLaunch.markSeen();
    if (!mounted) return;
    setState(() {
      _seen = Future.value(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iMaculate',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Localization wiring. The runtime auto-picks the user's
      // preferred locale; English is the fallback.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: FutureBuilder<bool>(
        future: _seen,
        builder: (context, snap) {
          // Pre-resolution placeholder matches the splash background so the
          // window doesn't flash white while we read the marker file.
          if (!snap.hasData) {
            return const ColoredBox(color: Color(0xFF08060F));
          }
          if (snap.data == true) {
            return const HomeShell();
          }
          return SplashScreen(onComplete: _completeIntro);
        },
      ),
    );
  }
}
