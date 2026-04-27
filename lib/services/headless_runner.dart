import 'dart:io';

import '../data/cleaning_targets.dart';
import '../models/clean_event.dart';
import '../models/cleaning_level.dart';
import '../models/scan_schedule.dart';
import 'app_support_paths.dart';
import 'archive_trash_service.dart';
import 'cache_remover.dart';
import 'cache_scanner.dart';
import 'disk_scanner.dart';
import 'exclusion_service.dart';
import 'first_launch_service.dart';
import 'history_service.dart';
import 'installed_apps_service.dart';
import 'launch_items_service.dart';
import 'launchd_agent_service.dart';
import '../models/launch_item.dart' show LaunchScopeInfo;
import 'restore_log.dart';
import 'schedule_service.dart';
import 'threat_definitions_service.dart';
import 'threat_scanner.dart';

/// Runs maintenance tasks without spinning up Flutter / the GUI. The
/// binary is the same — `Contents/MacOS/Sweep` — but invoked with
/// `--headless <subcommand …>` so launchd, cron, ssh, or the user
/// themselves can drive every Sweep behaviour from a terminal.
///
/// Subcommand surface mirrors the GUI 1:1 — see `_printHelp()` for the
/// full list. Every mutation that the GUI logs to History or the
/// restore log keeps doing so when invoked from the CLI, so the next
/// GUI session sees a coherent record.
class HeadlessRunner {
  HeadlessRunner({
    HistoryService? history,
    ScheduleService? schedule,
    ThreatDefinitionsService? defs,
    ExclusionService? exclusions,
    LaunchItemsService? launchItems,
    InstalledAppsService? installedApps,
    LaunchdAgentService? agent,
    ArchiveTrashService? archive,
    RestoreLog? restoreLog,
    FirstLaunchService? firstLaunch,
  })  : _history = history ?? HistoryService(),
        _schedule = schedule ?? ScheduleService(),
        _defs = defs ?? ThreatDefinitionsService(),
        _exclusions = exclusions ?? ExclusionService(),
        _launchItems = launchItems ?? LaunchItemsService(),
        _installedApps = installedApps ?? InstalledAppsService(),
        _agent = agent ?? LaunchdAgentService(),
        _archive = archive ?? ArchiveTrashService(),
        _restoreLog = restoreLog ?? RestoreLog(),
        _firstLaunch = firstLaunch ?? FirstLaunchService();

  final HistoryService _history;
  final ScheduleService _schedule;
  final ThreatDefinitionsService _defs;
  final ExclusionService _exclusions;
  final LaunchItemsService _launchItems;
  final InstalledAppsService _installedApps;
  final LaunchdAgentService _agent;
  final ArchiveTrashService _archive;
  final RestoreLog _restoreLog;
  final FirstLaunchService _firstLaunch;

  Future<int> run(List<String> args) async {
    final positional = _positionalArgs(args);
    final task = positional.isEmpty ? 'help' : positional.first;
    final rest = positional.skip(1).toList();
    _log('headless start · task=$task · pid=$pid');
    try {
      final code = await _dispatch(task, rest);
      _log('headless exit · task=$task · code=$code');
      return code;
    } catch (e, st) {
      stderr.writeln('headless error · task=$task · $e\n$st');
      return 2;
    }
  }

  Future<int> _dispatch(String task, List<String> args) async {
    switch (task) {
      // ---- Bulk / scheduled ---- ------------------------------------
      case 'scheduled-job':
        await _runScheduledJob();
        return 0;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        return 0;

      // ---- Cleaner modes ---- ---------------------------------------
      case 'light-scrub':
        await _runCleaningMode(CleaningLevel.lightScrub, privileged: false);
        return 0;
      case 'boilwash':
        await _runCleaningMode(CleaningLevel.boilwash, privileged: false);
        return 0;
      case 'sandblast':
        await _runCleaningMode(CleaningLevel.sandblast,
            privileged: _wantsPrivileged(args));
        return 0;
      case 'development':
        await _runCleaningMode(CleaningLevel.development, privileged: false);
        return 0;

      // ---- Threats ----  --------------------------------------------
      case 'update-defs':
        await _updateDefs();
        return 0;
      case 'scan-threats':
        await _scanThreats();
        return 0;

      // ---- Tree map ----  -------------------------------------------
      case 'tree-map':
        return _printTreeMap(args);

      // ---- Exclusions ----  -----------------------------------------
      case 'exclusions':
        return _exclusionsCmd(args);

      // ---- Schedule ----  -------------------------------------------
      case 'schedule':
        return _scheduleCmd(args);

      // ---- Launchd agent ----  --------------------------------------
      case 'agent':
        return _agentCmd(args);

      // ---- Launch items ----  ---------------------------------------
      case 'launch-items':
        return _launchItemsCmd(args);

      // ---- Uninstaller ----  ----------------------------------------
      case 'list-apps':
        return _listApps();
      case 'uninstall':
        return _uninstallCmd(args);

      // ---- History / restore ----  ----------------------------------
      case 'history':
        return _historyCmd(args);
      case 'restore':
        return _restoreCmd(args);

      // ---- Onboarding ----  -----------------------------------------
      case 'reset-onboarding':
        await _firstLaunch.reset();
        stdout.writeln('Onboarding markers cleared. Relaunch the GUI '
            'to replay splash → tour → walkthrough.');
        return 0;

      default:
        stderr.writeln('Unknown task: $task');
        _printHelp();
        return 1;
    }
  }

  // =====================================================================
  // Bulk / scheduled
  // =====================================================================

  Future<void> _runScheduledJob() async {
    final s = await _schedule.read();
    if (s.frequency == ScheduleFrequency.off) {
      _log('schedule off — nothing to do');
      return;
    }
    _log('schedule=${s.frequency.name} '
        'lightScrub=${s.runLightScrub} '
        'threatScan=${s.runThreatScan} '
        'updateDefs=${s.updateDefinitions}');
    if (s.runLightScrub) {
      await _runCleaningMode(CleaningLevel.lightScrub, privileged: false);
    }
    if (s.updateDefinitions) {
      await _updateDefs();
    }
    if (s.runThreatScan) {
      await _scanThreats();
    }
    await _schedule.markRanNow();
  }

  // =====================================================================
  // Cleaner modes
  // =====================================================================

  Future<void> _runCleaningMode(
    CleaningLevel level, {
    required bool privileged,
  }) async {
    _log('cleaning · ${level.name} · privileged=$privileged');
    final scanner =
        CacheScanner(privileged: privileged, exclusions: _exclusions);
    final remover = CacheRemover(privileged: privileged);
    final entries = await scanner.scan(targetsFor(level));
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
      } catch (err) {
        stderr.writeln('clean failed for ${e.target.name}: $err');
      }
    }
    if (logged.isNotEmpty) {
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: '${level.name}_headless',
        totalBytes: bytes,
        entries: logged,
      ));
    }
    stdout.writeln('Reclaimed ${_humanBytes(bytes)} via ${level.title}.');
  }

  // =====================================================================
  // Threats
  // =====================================================================

  Future<void> _updateDefs() async {
    _log('updating threat definitions…');
    final next = await _defs.update();
    stdout.writeln(
        'Definitions updated · ${next.signatures.length} signatures');
  }

  Future<void> _scanThreats() async {
    final defs = await _defs.read();
    if (defs.signatures.isEmpty) {
      stdout.writeln(
          'No definitions loaded — run `--headless update-defs` first.');
      return;
    }
    final scanner = ThreatScanner(definitions: defs);
    final home = Platform.environment['HOME'] ?? '';
    final targets = <String>[
      '/Applications',
      if (home.isNotEmpty) '$home/Downloads',
      if (home.isNotEmpty) '$home/Library/LaunchAgents',
    ];
    final hits = <ThreatHit>[];
    await for (final p in scanner.scan(targets)) {
      if (p.finished) {
        hits
          ..clear()
          ..addAll(p.hits);
        stdout.writeln('Scanned ${p.filesScanned} files · '
            '${p.hitsCount} hit${p.hitsCount == 1 ? "" : "s"}.');
      }
    }
    if (hits.isEmpty) return;
    await _history.append(CleanEvent(
      timestamp: DateTime.now(),
      mode: 'threat_scan_headless',
      totalBytes: hits.fold<int>(0, (a, h) => a + h.sizeBytes),
      entries: hits
          .map((h) => CleanEventEntry(
                path: h.path,
                name: h.signature.name.isEmpty
                    ? 'Unknown family'
                    : h.signature.name,
                sizeBytes: h.sizeBytes,
                disposition: 'detected',
              ))
          .toList(),
    ));
    for (final h in hits) {
      stderr.writeln('THREAT · ${h.path} · ${h.signature.name}');
    }
  }

  // =====================================================================
  // Tree map
  // =====================================================================

  Future<int> _printTreeMap(List<String> args) async {
    final basePath = args.isEmpty
        ? (Platform.environment['HOME'] ?? '/')
        : args.first;
    stdout.writeln('Scanning $basePath …');
    final scanner = DiskScanner();
    await for (final p in scanner.scan(basePath)) {
      if (!p.finished) continue;
      final list = p.entries.take(20).toList();
      for (final e in list) {
        stdout.writeln(
            '${_humanBytes(e.size).padLeft(10)}  ${e.name}');
      }
      stdout.writeln(
          '${list.length} of ${p.entries.length} top entries shown.');
    }
    return 0;
  }

  // =====================================================================
  // Exclusions
  // =====================================================================

  Future<int> _exclusionsCmd(List<String> args) async {
    if (args.isEmpty || args.first == 'list') {
      final list = await _exclusions.readAll();
      if (list.isEmpty) {
        stdout.writeln('(no exclusions)');
      } else {
        for (final p in list) {
          stdout.writeln(p);
        }
      }
      return 0;
    }
    if (args.first == 'add') {
      if (args.length < 2) {
        stderr.writeln('Usage: exclusions add <path>');
        return 1;
      }
      await _exclusions.add(_expand(args[1]));
      stdout.writeln('Added ${_expand(args[1])}.');
      return 0;
    }
    if (args.first == 'remove' || args.first == 'rm') {
      if (args.length < 2) {
        stderr.writeln('Usage: exclusions remove <path>');
        return 1;
      }
      await _exclusions.remove(_expand(args[1]));
      stdout.writeln('Removed ${_expand(args[1])}.');
      return 0;
    }
    stderr.writeln('Unknown exclusions subcommand: ${args.first}');
    return 1;
  }

  // =====================================================================
  // Schedule
  // =====================================================================

  Future<int> _scheduleCmd(List<String> args) async {
    if (args.isEmpty || args.first == 'status') {
      final s = await _schedule.read();
      stdout.writeln('frequency: ${s.frequency.name}');
      stdout.writeln('runLightScrub: ${s.runLightScrub}');
      stdout.writeln('runThreatScan: ${s.runThreatScan}');
      stdout.writeln('updateDefinitions: ${s.updateDefinitions}');
      stdout.writeln(
          'backgroundAgentInstalled: ${s.backgroundAgentInstalled}');
      stdout.writeln('lastRunAt: ${s.lastRunAt?.toIso8601String() ?? "—"}');
      return 0;
    }
    if (args.first == 'set') {
      if (args.length < 2) {
        stderr.writeln(
            'Usage: schedule set <off|daily|weekly|monthly> [tasks…]');
        stderr.writeln(
            'Tasks: --light-scrub --threat-scan --update-defs '
            '--no-light-scrub …');
        return 1;
      }
      final freq = ScheduleFrequency.values.firstWhere(
        (f) => f.name == args[1],
        orElse: () => ScheduleFrequency.off,
      );
      var s = (await _schedule.read()).copyWith(frequency: freq);
      for (final flag in args.skip(2)) {
        switch (flag) {
          case '--light-scrub':
            s = s.copyWith(runLightScrub: true);
          case '--no-light-scrub':
            s = s.copyWith(runLightScrub: false);
          case '--threat-scan':
            s = s.copyWith(runThreatScan: true);
          case '--no-threat-scan':
            s = s.copyWith(runThreatScan: false);
          case '--update-defs':
            s = s.copyWith(updateDefinitions: true);
          case '--no-update-defs':
            s = s.copyWith(updateDefinitions: false);
        }
      }
      await _schedule.write(s);
      // Re-bootstrap the agent if it's installed so the new
      // calendar interval takes effect.
      if (s.backgroundAgentInstalled) {
        await _agent.install(s);
      }
      stdout.writeln('Schedule updated.');
      return 0;
    }
    stderr.writeln('Unknown schedule subcommand: ${args.first}');
    return 1;
  }

  // =====================================================================
  // launchd agent
  // =====================================================================

  Future<int> _agentCmd(List<String> args) async {
    if (args.isEmpty || args.first == 'status') {
      final installed = await _agent.isInstalled();
      stdout.writeln(installed ? 'installed' : 'not installed');
      stdout.writeln('plist: ${_agent.plistPath}');
      return 0;
    }
    if (args.first == 'install') {
      final s = await _schedule.read();
      if (s.frequency == ScheduleFrequency.off) {
        stderr.writeln(
            'Set a schedule first: schedule set <daily|weekly|monthly>');
        return 1;
      }
      final r = await _agent.install(s);
      if (!r.ok) {
        stderr.writeln('Install failed: ${r.message}');
        return 2;
      }
      await _schedule
          .write(s.copyWith(backgroundAgentInstalled: true));
      stdout.writeln('Agent installed at ${_agent.plistPath}.');
      return 0;
    }
    if (args.first == 'uninstall') {
      final r = await _agent.uninstall();
      if (!r.ok) {
        stderr.writeln('Uninstall failed: ${r.message}');
        return 2;
      }
      final s = await _schedule.read();
      await _schedule
          .write(s.copyWith(backgroundAgentInstalled: false));
      stdout.writeln('Agent uninstalled.');
      return 0;
    }
    stderr.writeln('Unknown agent subcommand: ${args.first}');
    return 1;
  }

  // =====================================================================
  // Launch items
  // =====================================================================

  Future<int> _launchItemsCmd(List<String> args) async {
    if (args.isEmpty || args.first == 'list') {
      final items = await _launchItems.scan();
      for (final i in items) {
        final flag = i.suspicious ? '!' : ' ';
        stdout.writeln('$flag ${i.scope.label.padRight(22)} '
            '${i.label}  →  ${i.program ?? "(?)"}');
      }
      stdout.writeln('${items.length} item${items.length == 1 ? "" : "s"} '
          '(prefixed `!` = flagged suspicious).');
      return 0;
    }
    if (args.first == 'remove' || args.first == 'rm') {
      if (args.length < 2) {
        stderr.writeln('Usage: launch-items remove <plist-path-or-label>');
        return 1;
      }
      final needle = args[1];
      final items = await _launchItems.scan();
      final match = items.firstWhere(
        (i) => i.plistPath == needle || i.label == needle,
        orElse: () => throw 'No launch item matched "$needle"',
      );
      final entry = await _archive.archiveAndTrash(
        label: match.label,
        kind: 'launch_item',
        sourcePaths: [match.plistPath],
      );
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'launch_item_headless',
        totalBytes: entry.totalBytes,
        entries: [
          CleanEventEntry(
            path: match.plistPath,
            name: match.label,
            sizeBytes: entry.totalBytes,
            disposition: 'archived_in_trash',
          ),
        ],
        restoreId: entry.id,
      ));
      stdout.writeln('Disabled ${match.label} '
          '(restore id: ${entry.id}).');
      return 0;
    }
    stderr.writeln('Unknown launch-items subcommand: ${args.first}');
    return 1;
  }

  // =====================================================================
  // Uninstaller
  // =====================================================================

  Future<int> _listApps() async {
    final apps = await _installedApps.scan();
    for (final a in apps) {
      stdout.writeln('${_humanBytes(a.totalBytes).padLeft(10)}  '
          '${(a.bundleId ?? "—").padRight(40)}  ${a.name}');
    }
    stdout.writeln('${apps.length} apps found.');
    return 0;
  }

  Future<int> _uninstallCmd(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln(
          'Usage: uninstall <bundle-id|app-name|.app path>');
      return 1;
    }
    final needle = args.first;
    final apps = await _installedApps.scan();
    final match = apps.firstWhere(
      (a) =>
          a.bundleId == needle ||
          a.name == needle ||
          a.bundlePath == needle ||
          a.bundlePath.endsWith('/$needle'),
      orElse: () => throw 'No app matched "$needle"',
    );
    final sources = <String>[
      match.bundlePath,
      ...match.leftovers.map((l) => l.path),
    ];
    final entry = await _archive.archiveAndTrash(
      label: match.name,
      kind: 'uninstall',
      sourcePaths: sources,
    );
    await _history.append(CleanEvent(
      timestamp: DateTime.now(),
      mode: 'uninstall_headless',
      totalBytes: entry.totalBytes,
      entries: entry.items
          .map((i) => CleanEventEntry(
                path: i.originalPath,
                name: '${match.name} · ${i.archiveRelPath}',
                sizeBytes: i.sizeBytes,
                disposition: 'archived_in_trash',
              ))
          .toList(),
      restoreId: entry.id,
    ));
    stdout.writeln(
        'Uninstalled ${match.name} (restore id: ${entry.id}).');
    return 0;
  }

  // =====================================================================
  // History / restore
  // =====================================================================

  Future<int> _historyCmd(List<String> args) async {
    final limit = args.isEmpty ? 20 : (int.tryParse(args.first) ?? 20);
    final events = await _history.readAll();
    for (final e in events.take(limit)) {
      stdout.writeln(
          '${e.timestamp.toIso8601String().padRight(28)} '
          '${e.mode.padRight(28)} '
          '${_humanBytes(e.totalBytes).padLeft(10)} '
          '${e.restoreId == null ? "" : "restore=${e.restoreId}"}');
    }
    stdout.writeln('${events.length} total events; showing $limit.');
    return 0;
  }

  Future<int> _restoreCmd(List<String> args) async {
    if (args.isEmpty) {
      // List restorable entries.
      final entries = await _restoreLog.readAll();
      for (final e in entries) {
        stdout.writeln('${e.id}  ${e.kind.padRight(20)}  '
            '${_humanBytes(e.totalBytes).padLeft(10)}  ${e.label}');
      }
      stdout.writeln('${entries.length} restorable entries.');
      return 0;
    }
    final id = args.first;
    final result = await _archive.restore(id);
    if (result.allSucceeded) {
      stdout.writeln('Restored ${result.restored.length} '
          '${result.restored.length == 1 ? "item" : "items"}.');
      return 0;
    }
    for (final f in result.failures) {
      stderr.writeln('FAIL · $f');
    }
    return result.restored.isEmpty ? 2 : 1;
  }

  // =====================================================================
  // Helpers
  // =====================================================================

  /// Strips `--headless` and any leading flags, returns the remaining
  /// positional args (subcommand + its parameters).
  List<String> _positionalArgs(List<String> args) {
    final after = args.skipWhile((a) => a != '--headless').skip(1).toList();
    return after.where((a) => true).toList();
  }

  bool _wantsPrivileged(List<String> args) =>
      args.contains('--admin') || args.contains('--privileged');

  String _expand(String path) {
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home${path.substring(1)}';
    }
    if (path == '~') return Platform.environment['HOME'] ?? path;
    return path;
  }

  String _humanBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _printHelp() {
    stdout.writeln('Sweep headless / CLI');
    stdout.writeln('');
    stdout.writeln('Usage:  Sweep --headless <subcommand> [args]');
    stdout.writeln('');
    stdout.writeln('Cleaning modes:');
    stdout.writeln('  light-scrub                 Empty user caches '
        '+ logs');
    stdout.writeln('  boilwash                    User caches + xcode '
        'derived data + iOS sim caches');
    stdout.writeln('  sandblast [--admin]         Deep clean — needs '
        'admin for /Library + /var');
    stdout.writeln('  development                 Build-tool caches '
        '(npm, gradle, cargo, …)');
    stdout.writeln('');
    stdout.writeln('Threats:');
    stdout.writeln('  update-defs                 Pull latest '
        'signatures from MalwareBazaar');
    stdout.writeln('  scan-threats                Hash-match scan; '
        'hits go to History');
    stdout.writeln('');
    stdout.writeln('Disk:');
    stdout.writeln('  tree-map [path]             Print top-20 '
        'entries by size (defaults to \$HOME)');
    stdout.writeln('  list-apps                   List installed apps + '
        'leftover sizes');
    stdout.writeln('  uninstall <id|name|path>    Archive + remove an app');
    stdout.writeln('');
    stdout.writeln('Exclusions:');
    stdout.writeln('  exclusions list');
    stdout.writeln('  exclusions add <path>');
    stdout.writeln('  exclusions remove <path>');
    stdout.writeln('');
    stdout.writeln('Schedule:');
    stdout.writeln('  schedule status');
    stdout.writeln('  schedule set <off|daily|weekly|monthly> '
        '[--light-scrub] [--threat-scan] [--update-defs]');
    stdout.writeln('  scheduled-job               Run the configured '
        'job once (what launchd invokes)');
    stdout.writeln('');
    stdout.writeln('launchd agent:');
    stdout.writeln('  agent status');
    stdout.writeln('  agent install               Write + bootstrap '
        '~/Library/LaunchAgents/dev.willmarch.sweep.scheduler.plist');
    stdout.writeln('  agent uninstall             Bootout + delete the plist');
    stdout.writeln('');
    stdout.writeln('Launch items:');
    stdout.writeln('  launch-items list');
    stdout.writeln('  launch-items remove <plist-path-or-label>');
    stdout.writeln('');
    stdout.writeln('History / restore:');
    stdout.writeln('  history [limit]             Print recent events '
        '(default 20)');
    stdout.writeln('  restore                     List restorable '
        'archive entries');
    stdout.writeln('  restore <id>                Restore an archived '
        'deletion in place');
    stdout.writeln('');
    stdout.writeln('Maintenance:');
    stdout.writeln('  reset-onboarding            Clear splash / tour '
        '/ walkthrough markers');
    stdout.writeln('  help                        This message');
  }

  void _log(String msg) {
    final stamp = DateTime.now().toIso8601String();
    final line = '[$stamp] $msg\n';
    stdout.write(line);
    () async {
      try {
        final root = await AppSupportPaths.ensureRoot();
        final logs = Directory('${root.path}/logs');
        if (!await logs.exists()) await logs.create(recursive: true);
        final f = File('${logs.path}/headless.log');
        await f.writeAsString(line, mode: FileMode.append);
      } catch (_) {/* non-fatal */}
    }();
  }
}
