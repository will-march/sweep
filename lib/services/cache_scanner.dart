import 'dart:io';

import '../models/cache_entry.dart';
import '../models/cache_target.dart';
import 'exclusion_service.dart';
import 'path_resolver.dart';

class CacheScanner {
  final bool privileged;

  /// Optional user-managed list of paths the scanner must skip. The
  /// service is loaded once (matchesAnySync) at the start of [scan]
  /// so the per-target check is cheap.
  final ExclusionService? exclusions;

  CacheScanner({required this.privileged, this.exclusions});

  Future<List<CacheEntry>> scan(List<CacheTarget> targets) async {
    final ex = exclusions;
    if (ex != null) await ex.readAll();

    final results = <CacheEntry>[];
    for (final t in targets) {
      final resolved = expandPath(t.path);
      if (ex != null && ex.matchesAnySync(resolved)) continue;
      final dir = Directory(resolved);
      if (!dir.existsSync()) continue;
      final size = await _measure(dir);
      results.add(CacheEntry(target: t, directory: dir, sizeBytes: size));
    }
    return results;
  }

  Future<int> _measure(Directory dir) async {
    if (privileged) {
      try {
        final r = await Process.run('du', ['-sk', dir.path]);
        if (r.exitCode == 0) {
          final kb = int.tryParse(r.stdout.toString().split('\t').first) ?? 0;
          return kb * 1024;
        }
      } catch (_) {/* fall through */}
    }
    return _walk(dir);
  }

  Future<int> _walk(Directory dir) async {
    var total = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {/* unreadable file */}
        }
      }
    } catch (_) {/* unreadable dir */}
    return total;
  }
}
