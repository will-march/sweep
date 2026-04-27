import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/headless_runner.dart';

/// Entry point. The same binary serves two roles:
///   1. **GUI** — `runApp(SweepApp)`. The default.
///   2. **Headless** — when launched with `--headless <task>`, run the
///      task and exit. launchd uses this so scheduled cleans / scans
///      / definitions updates can fire even when nobody opened the
///      app today.
///
/// macOS doesn't pass argv into Dart's `main`. We pull the runtime
/// args from `Platform.executableArguments` (= `NSProcessInfo`'s
/// arguments minus argv[0]).
Future<void> main() async {
  // macOS's NSApplicationMain consumes argv before Dart sees it via
  // Platform.executableArguments — so for a packaged .app we can't
  // read CLI flags that way. Workaround: ask `ps` for our own
  // process's args, which always reflects what the user typed.
  final args = await _readOwnArgs();
  if (args.contains('--headless')) {
    final code = await HeadlessRunner().run(args);
    exit(code);
  }
  runApp(const SweepApp());
}

Future<List<String>> _readOwnArgs() async {
  // Try the dart-side accessor first — it works for `dart compile exe`
  // builds and for `flutter test`. If empty (Flutter macOS app), fall
  // back to ps -p $pid -o args=.
  final fromDart = Platform.executableArguments;
  if (fromDart.isNotEmpty) return fromDart;
  try {
    final r = await Process.run('ps', ['-p', '$pid', '-o', 'args=']);
    if (r.exitCode != 0) return const [];
    final line = r.stdout.toString().trim();
    if (line.isEmpty) return const [];
    // Drop argv[0]; whitespace-split the rest. Args with embedded
    // spaces are rare for our flag-style CLI and would need shell
    // quoting either way.
    final parts = line.split(RegExp(r'\s+'));
    return parts.skip(1).toList();
  } catch (_) {
    return const [];
  }
}
