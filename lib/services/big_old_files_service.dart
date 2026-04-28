import 'dart:io';

import '../models/big_old_file.dart';
import 'exclusion_service.dart';

/// Walks a user-chosen root and reports files that are both large
/// *and* haven't been touched recently. This is the "what's eating my
/// disk that I forgot about" report.
///
/// Defaults:
///   - minSize: 100 MB. Smaller files don't move the needle.
///   - minAge:  180 days. Six months untouched is the "really stale"
///     line most people draw.
///
/// We deliberately skip:
///   - `.app` bundles (those are Applications, handled by Uninstaller)
///   - Hidden dotdirs (.git, .DS_Store, …)
///   - `Library` system folders — those are caches, handled elsewhere.
class BigOldFilesService {
  final ExclusionService? exclusions;
  BigOldFilesService({this.exclusions});

  Future<List<BigOldFile>> scan({
    required String rootPath,
    int minSizeBytes = 100 * 1024 * 1024,
    Duration minAge = const Duration(days: 180),
    int limit = 500,
    void Function(String currentPath)? onProgress,
  }) async {
    await exclusions?.readAll();
    final root = Directory(rootPath);
    if (!await root.exists()) return const [];
    final cutoff = DateTime.now().subtract(minAge);
    final out = <BigOldFile>[];
    await _walk(
      root,
      cutoff,
      minSizeBytes,
      out,
      limit,
      onProgress,
    );
    out.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    if (out.length > limit) out.removeRange(limit, out.length);
    return out;
  }

  Future<void> _walk(
    Directory dir,
    DateTime cutoff,
    int minSize,
    List<BigOldFile> sink,
    int limit,
    void Function(String currentPath)? onProgress,
  ) async {
    if (sink.length >= limit * 2) return;
    if (exclusions?.matchesAnySync(dir.path) ?? false) return;
    onProgress?.call(dir.path);

    Stream<FileSystemEntity> stream;
    try {
      stream = dir.list(followLinks: false);
    } catch (_) {
      return;
    }
    await for (final e in stream) {
      final name = _basename(e.path);
      if (name.startsWith('.')) continue;

      if (e is Directory) {
        if (e.path.endsWith('.app')) continue;
        if (e.path.endsWith('/Library')) continue;
        await _walk(e, cutoff, minSize, sink, limit, onProgress);
      } else if (e is File) {
        try {
          final s = await e.stat();
          if (s.size < minSize) continue;
          // accessed sometimes lags or returns mtime on macOS depending
          // on the filesystem; take the most recent of the two.
          final lastUsed = s.accessed.isAfter(s.modified)
              ? s.accessed
              : s.modified;
          if (lastUsed.isAfter(cutoff)) continue;
          sink.add(BigOldFile(
            path: e.path,
            sizeBytes: s.size,
            lastUsed: lastUsed,
          ));
        } catch (_) {/* skip */}
      }
    }
  }

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }
}
