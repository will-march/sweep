import 'dart:convert';
import 'dart:io';

import 'app_support_paths.dart';

/// User-editable list of paths the cleaner / scanner must never touch.
/// Persisted as JSON at
/// ~/Library/Application Support/Sweep/exclusions.json.
///
/// Matching is *prefix-based*: an exclusion of `~/Library/Caches/Foo`
/// also covers `~/Library/Caches/Foo/inner.bin`. This matches user
/// expectation ("don't touch this folder, ever").
class ExclusionService {
  static const fileName = 'exclusions.json';

  final String? overridePath;
  ExclusionService({this.overridePath});

  String get _path => overridePath ?? AppSupportPaths.fileFor(fileName);

  /// In-memory cache so hot paths (matchesAny) don't read disk on every
  /// call. Loaded on first read, refreshed on every write.
  List<String>? _cache;

  Future<List<String>> readAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    final f = File(_path);
    if (!await f.exists()) {
      _cache = [];
      return const [];
    }
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) {
        _cache = [];
        return const [];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list.cast<String>();
      return List.unmodifiable(_cache!);
    } catch (_) {
      _cache = [];
      return const [];
    }
  }

  Future<void> add(String path) async {
    final all = (await readAll()).toList();
    final normalised = _normalise(path);
    if (normalised.isEmpty) return;
    if (all.contains(normalised)) return;
    all.add(normalised);
    await _writeAll(all);
  }

  Future<void> remove(String path) async {
    final all = (await readAll()).toList();
    if (all.remove(path)) {
      await _writeAll(all);
    }
  }

  Future<void> _writeAll(List<String> paths) async {
    if (overridePath == null) {
      await AppSupportPaths.ensureRoot();
    } else {
      final dir = File(_path).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    await File(_path).writeAsString(jsonEncode(paths));
    _cache = paths;
  }

  /// True when [candidate] matches any current exclusion (prefix or
  /// exact match). Synchronous so scanner inner loops can call it
  /// cheaply — assumes [readAll] was awaited at scan start.
  bool matchesAnySync(String candidate) {
    final list = _cache;
    if (list == null || list.isEmpty) return false;
    for (final ex in list) {
      if (candidate == ex) return true;
      if (candidate.startsWith('$ex/')) return true;
    }
    return false;
  }

  /// Async variant for callers that haven't pre-loaded the list yet.
  Future<bool> matchesAny(String candidate) async {
    await readAll();
    return matchesAnySync(candidate);
  }

  String _normalise(String p) {
    var s = p.trim();
    while (s.endsWith('/') && s.length > 1) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
