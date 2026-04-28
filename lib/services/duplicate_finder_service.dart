import 'dart:io';

import '../models/duplicate_group.dart';
import 'exclusion_service.dart';

/// Finds groups of byte-identical files inside a user-chosen root.
///
/// Two-pass:
///   1. Walk the tree and bucket every file by exact size. Any bucket
///      with one entry can't possibly be a duplicate, so it's dropped.
///   2. For each multi-entry bucket, compute SHA-256 via the system
///      `shasum -a 256` (already installed on every Mac, no Dart deps).
///      Same hash + same size = duplicate.
///
/// We skip:
///   - hidden dotdirs (`.git`, `.DS_Store`, …)
///   - macOS app bundles
///   - empty files (0 bytes is not a useful match)
///   - files smaller than [minSizeBytes] — the default 1 MB filters
///     out the long tail of small dotfiles where collisions are common
///     but the reclaim is negligible.
class DuplicateFinderService {
  final ExclusionService? exclusions;
  DuplicateFinderService({this.exclusions});

  Future<List<DuplicateGroup>> scan({
    required String rootPath,
    int minSizeBytes = 1024 * 1024,
    int maxFiles = 50000,
    void Function(String currentPath)? onProgress,
  }) async {
    await exclusions?.readAll();
    final root = Directory(rootPath);
    if (!await root.exists()) return const [];

    // Pass 1: bucket by size.
    final bySize = <int, List<String>>{};
    final scanned = <int>[0];
    await _walk(root, bySize, minSizeBytes, scanned, maxFiles, onProgress);

    // Pass 2: hash candidates.
    final groups = <DuplicateGroup>[];
    for (final entry in bySize.entries) {
      final paths = entry.value;
      if (paths.length < 2) continue;
      final byHash = <String, List<String>>{};
      for (final p in paths) {
        onProgress?.call(p);
        final h = await _sha256(p);
        if (h == null) continue;
        byHash.putIfAbsent(h, () => []).add(p);
      }
      for (final hashEntry in byHash.entries) {
        if (hashEntry.value.length < 2) continue;
        groups.add(DuplicateGroup(
          sizeBytes: entry.key,
          hash: hashEntry.key,
          paths: hashEntry.value,
        ));
      }
    }
    groups.sort((a, b) =>
        b.reclaimableBytes.compareTo(a.reclaimableBytes));
    return groups;
  }

  Future<void> _walk(
    Directory dir,
    Map<int, List<String>> bySize,
    int minSize,
    List<int> scanned,
    int maxFiles,
    void Function(String currentPath)? onProgress,
  ) async {
    if (scanned[0] >= maxFiles) return;
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
        await _walk(e, bySize, minSize, scanned, maxFiles, onProgress);
      } else if (e is File) {
        try {
          final s = await e.stat();
          if (s.size < minSize) continue;
          bySize.putIfAbsent(s.size, () => []).add(e.path);
          scanned[0]++;
          if (scanned[0] >= maxFiles) return;
        } catch (_) {/* skip */}
      }
    }
  }

  Future<String?> _sha256(String path) async {
    try {
      final r = await Process.run('shasum', ['-a', '256', path]);
      if (r.exitCode != 0) return null;
      final out = r.stdout.toString().trim();
      // shasum prints `<hex>  <path>` — keep only the hex.
      final space = out.indexOf(' ');
      return space > 0 ? out.substring(0, space) : null;
    } catch (_) {
      return null;
    }
  }

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }
}
