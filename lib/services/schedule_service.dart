import 'dart:convert';
import 'dart:io';

import '../models/scan_schedule.dart';
import 'app_support_paths.dart';

/// Persists [ScanSchedule] under
/// ~/Library/Application Support/Sweep/schedule.json.
///
/// True background scheduling on macOS belongs in a launchd agent —
/// we'd register one via SMAppService for "wake up the cleaner once a
/// week even when Sweep is closed". Until that helper ships, this
/// service is the source of truth and the in-app runner polls it while
/// the app is open.
class ScheduleService {
  static const fileName = 'schedule.json';

  final String? overridePath;
  ScheduleService({this.overridePath});

  String get _path => overridePath ?? AppSupportPaths.fileFor(fileName);

  Future<ScanSchedule> read() async {
    final f = File(_path);
    if (!await f.exists()) return ScanSchedule.off;
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return ScanSchedule.off;
      return ScanSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ScanSchedule.off;
    }
  }

  Future<void> write(ScanSchedule schedule) async {
    if (overridePath == null) {
      await AppSupportPaths.ensureRoot();
    } else {
      final dir = File(_path).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    await File(_path).writeAsString(jsonEncode(schedule.toJson()));
  }

  Future<void> markRanNow() async {
    final s = await read();
    await write(s.copyWith(lastRunAt: DateTime.now()));
  }
}
