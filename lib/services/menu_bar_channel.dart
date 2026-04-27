import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cleaning_targets.dart';
import '../models/clean_event.dart';
import '../models/cleaning_level.dart';
import 'cache_remover.dart';
import 'cache_scanner.dart';
import 'cli_installer_service.dart';
import 'exclusion_service.dart';
import 'history_service.dart';
import 'schedule_service.dart';
import 'threat_definitions_service.dart';

/// Dart-side handler for the `sweep.menubar` MethodChannel.
///
/// The Swift NSStatusItem in `MainFlutterWindow` invokes Dart-side
/// methods on this channel when the user picks an item from the menu
/// bar. We wire those calls into the same services the GUI uses so
/// behaviour stays consistent.
///
/// The handler runs *inside* the GUI process — it's the same isolate
/// as the rest of the Flutter app, so all our existing services work
/// unchanged. A separate `--headless` binary covers the launchd path.
class MenuBarChannel {
  static const _channelName = 'sweep.menubar';

  /// Global ScaffoldMessenger key so menu-bar handlers (which run
  /// outside any BuildContext) can show snackbars in the main window.
  /// MaterialApp wires this up via [scaffoldMessengerKey].
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Bind the channel handler. Optional [onOpenApp] is fired when the
  /// user picks "Open Sweep" so the host can also do an in-app
  /// nav (e.g. focus the cleaner screen).
  static void install({void Function()? onOpenApp}) {
    const channel = MethodChannel(_channelName);
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openApp':
          onOpenApp?.call();
          return null;
        case 'lightScrub':
          await _lightScrub();
          _toast('Light Scrub finished — see History.');
          return null;
        case 'updateDefs':
          await _updateDefs();
          _toast('Threat definitions updated.');
          return null;
        case 'threatScan':
          // The GUI's threat scan is a long-running streamed job and
          // surfacing live progress from a menu invocation is tricky.
          // For the menu bar's "fire-and-forget" UX we just kick off
          // a definitions refresh — the heavy scan stays on the
          // dedicated screen.
          await _updateDefs();
          _toast('Definitions refreshed. Open Threat Scan to run.');
          return null;
        case 'scheduledJob':
          await _scheduledJob();
          _toast('Scheduled job finished.');
          return null;
        case 'installCli':
          await _installCli();
          return null;
      }
      return null;
    });
  }

  static void _toast(String message) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Future<void> _installCli() async {
    final svc = CliInstallerService();
    final installed = await svc.isInstalled();
    final result = installed
        ? await svc.uninstall()
        : await svc.install();
    _toast(result.message);
  }

  static Future<void> _lightScrub() async {
    final scanner = CacheScanner(
      privileged: false,
      exclusions: ExclusionService(),
    );
    final remover = CacheRemover(privileged: false);
    final entries =
        await scanner.scan(targetsFor(CleaningLevel.lightScrub));
    var bytes = 0;
    final logged = <CleanEventEntry>[];
    for (final e in entries) {
      try {
        await remover.empty(e.directory, e.target.risk);
        if (e.sizeBytes > 0) {
          bytes += e.sizeBytes;
          logged.add(CleanEventEntry(
            path: e.directory.path,
            name: e.target.name,
            sizeBytes: e.sizeBytes,
            disposition: 'permanently_deleted',
          ));
        }
      } catch (_) {/* skip */}
    }
    if (logged.isNotEmpty) {
      await HistoryService().append(CleanEvent(
        timestamp: DateTime.now(),
        mode: '${CleaningLevel.lightScrub.name}_menubar',
        totalBytes: bytes,
        entries: logged,
      ));
    }
  }

  static Future<void> _updateDefs() async {
    try {
      await ThreatDefinitionsService().update();
    } catch (_) {/* surfacing is the GUI's job */}
  }

  static Future<void> _scheduledJob() async {
    final s = await ScheduleService().read();
    if (s.runLightScrub) await _lightScrub();
    if (s.updateDefinitions) await _updateDefs();
    await ScheduleService().markRanNow();
  }
}
