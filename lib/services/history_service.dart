import 'dart:convert';
import 'dart:io';

import '../models/clean_event.dart';
import 'app_support_paths.dart';

/// Reads and writes the cleaning history at
/// ~/Library/Application Support/Sweep/history.json.
///
/// History is a flat JSON array of [CleanEvent] objects, newest-first.
/// We cap at [maxEntries] so the file stays bounded; older events drop off.
class HistoryService {
  static const fileName = 'history.json';
  static const maxEntries = 500;

  /// Override the storage file in tests. Falls back to the real path
  /// under Application Support when null.
  final String? overridePath;
  HistoryService({this.overridePath});

  String get _path => overridePath ?? AppSupportPaths.fileFor(fileName);

  Future<List<CleanEvent>> readAll() async {
    final f = File(_path);
    if (!await f.exists()) return [];
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CleanEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt history isn't worth crashing the app — start fresh.
      return [];
    }
  }

  Future<void> append(CleanEvent event) async {
    if (overridePath == null) {
      await AppSupportPaths.ensureRoot();
    } else {
      final dir = File(_path).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    final all = await readAll();
    all.insert(0, event);
    if (all.length > maxEntries) {
      all.removeRange(maxEntries, all.length);
    }
    final f = File(_path);
    await f.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final f = File(_path);
    if (await f.exists()) await f.delete();
  }
}
