import 'dart:io';

import '../models/scan_schedule.dart';
import 'app_support_paths.dart';

/// Result of an install/uninstall call.
class LaunchdResult {
  final bool ok;
  final String? message;
  const LaunchdResult({required this.ok, this.message});
}

/// Manages our user-scope launchd agent at
/// `~/Library/LaunchAgents/com.imaculate.scheduler.plist`.
///
/// The plist re-runs the iMaculate binary in headless mode on the
/// user's chosen cadence so scheduled cleans / threat scans / defs
/// updates fire even when the GUI is closed. We write the plist
/// ourselves and bootstrap it via `launchctl bootstrap gui/$UID …`
/// (the modern replacement for `launchctl load`).
///
/// Daemons in `/Library/LaunchDaemons/` would need root + a real
/// privileged helper; that's out of scope for v1. User agents in
/// `~/Library/LaunchAgents/` cover the realistic "wake up at 3am
/// while my Mac is on" use case.
class LaunchdAgentService {
  static const label = 'com.imaculate.scheduler';

  /// Override the plist target dir in tests (writes there instead of
  /// the real `~/Library/LaunchAgents`). When null we read HOME.
  final String? overrideAgentDir;

  /// Override the executable that the agent invokes — defaults to
  /// `Platform.resolvedExecutable`, which points at the live binary.
  final String? overrideExecutable;

  /// Inject a runner for `launchctl` calls. Defaults to a real
  /// `Process.run`; tests pass a fake.
  final Future<ProcessResult> Function(String exe, List<String> args)?
      processRunner;

  LaunchdAgentService({
    this.overrideAgentDir,
    this.overrideExecutable,
    this.processRunner,
  });

  String get plistPath {
    final dir = overrideAgentDir ??
        '${Platform.environment['HOME'] ?? ''}/Library/LaunchAgents';
    return '$dir/$label.plist';
  }

  Future<bool> isInstalled() async => File(plistPath).existsSync();

  /// Render + write the plist for the given schedule, bootout any
  /// previous registration, and bootstrap the new one.
  Future<LaunchdResult> install(ScanSchedule schedule) async {
    if (schedule.frequency == ScheduleFrequency.off) {
      return uninstall();
    }
    final exec = overrideExecutable ?? Platform.resolvedExecutable;
    final logsDir = '${AppSupportPaths.root}/logs';
    final dir = Directory(_agentDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final logs = Directory(logsDir);
    if (!await logs.exists()) await logs.create(recursive: true);

    final xml = buildPlist(
      execPath: exec,
      schedule: schedule,
      logsDir: logsDir,
    );
    final tmp = File('$plistPath.tmp');
    await tmp.writeAsString(xml, flush: true);
    await tmp.rename(plistPath);

    // Bootout first (idempotent) so a frequency change picks up.
    await _runLaunchctl(['bootout', await _domain(), plistPath]);
    final r = await _runLaunchctl(['bootstrap', await _domain(), plistPath]);
    if (r.exitCode != 0) {
      return LaunchdResult(
        ok: false,
        message:
            'launchctl bootstrap exited ${r.exitCode}: ${r.stderr}'.trim(),
      );
    }
    return const LaunchdResult(ok: true);
  }

  /// Bootout + delete the plist.
  Future<LaunchdResult> uninstall() async {
    final f = File(plistPath);
    final existed = await f.exists();
    if (existed) {
      await _runLaunchctl(['bootout', await _domain(), plistPath]);
      try {
        await f.delete();
      } catch (_) {/* swallow */}
    }
    return const LaunchdResult(ok: true);
  }

  /// Visible to tests for golden-output assertions.
  String buildPlist({
    required String execPath,
    required ScanSchedule schedule,
    required String logsDir,
  }) {
    final calendar = _calendarBlock(schedule.frequency);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$execPath</string>
    <string>--headless</string>
    <string>scheduled-job</string>
  </array>
$calendar
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$logsDir/scheduler.out.log</string>
  <key>StandardErrorPath</key>
  <string>$logsDir/scheduler.err.log</string>
  <key>ProcessType</key>
  <string>Background</string>
  <key>LowPriorityIO</key>
  <true/>
  <key>Nice</key>
  <integer>10</integer>
</dict>
</plist>
''';
  }

  String _calendarBlock(ScheduleFrequency freq) {
    // 03:30 local time is the canonical "after backups, before
    // people wake up" window. macOS launchd respects local time for
    // StartCalendarInterval.
    return switch (freq) {
      ScheduleFrequency.daily => '''  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>30</integer>
  </dict>''',
      ScheduleFrequency.weekly => '''  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>0</integer>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>30</integer>
  </dict>''',
      ScheduleFrequency.monthly => '''  <key>StartCalendarInterval</key>
  <dict>
    <key>Day</key><integer>1</integer>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>30</integer>
  </dict>''',
      ScheduleFrequency.off => '',
    };
  }

  String get _agentDir => overrideAgentDir ??
      '${Platform.environment['HOME'] ?? ''}/Library/LaunchAgents';

  Future<String> _domain() async {
    // gui/<UID> is the user's Aqua session domain — where user
    // agents live in modern launchd terms. UID comes from `id -u`
    // rather than the env so a sudo-wrapped invocation still
    // targets the right session.
    final uid = await _uid();
    return 'gui/$uid';
  }

  Future<String> _uid() async {
    final runner = processRunner;
    final r = runner == null
        ? await Process.run('id', ['-u'])
        : await runner('id', ['-u']);
    return r.stdout.toString().trim();
  }

  Future<ProcessResult> _runLaunchctl(List<String> args) async {
    final runner = processRunner;
    if (args.isEmpty) {
      // Skip — used as a no-op poke from _domain when probing.
      return ProcessResult(0, 0, '', '');
    }
    if (runner != null) {
      return runner('launchctl', args);
    }
    return Process.run('launchctl', args);
  }
}
