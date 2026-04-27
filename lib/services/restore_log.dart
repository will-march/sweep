import 'dart:convert';
import 'dart:io';

import '../models/restore_entry.dart';
import 'app_support_paths.dart';

/// Persists the catalog of recoverable archived deletions at
/// ~/Library/Application Support/iMaculate/restore_log.json.
///
/// Schema is just a JSON array of [RestoreEntry], newest first. Capped
/// at [maxEntries] so the file stays bounded — once an entry rolls
/// off, the archive is still in Trash but iMaculate won't surface a
/// Restore button for it (user can still drag it out of Finder).
class RestoreLog {
  static const fileName = 'restore_log.json';
  static const maxEntries = 200;

  final String? overridePath;
  RestoreLog({this.overridePath});

  String get _path => overridePath ?? AppSupportPaths.fileFor(fileName);

  Future<List<RestoreEntry>> readAll() async {
    final f = File(_path);
    if (!await f.exists()) return [];
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RestoreEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> append(RestoreEntry entry) async {
    if (overridePath == null) {
      await AppSupportPaths.ensureRoot();
    } else {
      final dir = File(_path).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    final all = await readAll();
    all.insert(0, entry);
    if (all.length > maxEntries) {
      all.removeRange(maxEntries, all.length);
    }
    await File(_path)
        .writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<RestoreEntry?> findById(String id) async {
    final all = await readAll();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Drop a single entry (e.g. after the user successfully restored it
  /// or after we detect the archive is gone from Trash).
  Future<void> remove(String id) async {
    final all = await readAll();
    all.removeWhere((e) => e.id == id);
    await File(_path)
        .writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final f = File(_path);
    if (await f.exists()) await f.delete();
  }
}
