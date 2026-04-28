import 'dart:async';
import 'dart:io';

import '../models/orphan_cache.dart';
import 'exclusion_service.dart';

/// Walks the user's typical project roots looking for project-local
/// build/dependency caches: `node_modules`, `.venv`, `venv`, `target`,
/// `vendor`, `build`, `.gradle`, `.next`, `.nuxt`, `.turbo`,
/// `.pnpm-store`, `__pycache__`, `dist`. For each cache it reports the
/// project's last-touched mtime so the user can prune projects they
/// haven't worked on in months.
///
/// Walk strategy:
///   - Roots: ~/Documents, ~/Developer, ~/code, ~/Projects, ~/src,
///     ~/repos, ~/work, ~/dev, ~/Desktop. Add ~ itself last as a
///     low-priority fallback.
///   - Bounded depth (default 4). Project caches sit at depth 1–3 in
///     practice; going deeper just slows things down on monorepos.
///   - Stop descending once we've identified a cache directory — we
///     don't want to recurse into `node_modules/whatever/node_modules`.
class OrphanCachesService {
  /// Cache directory names we care about. Keep ordered roughly by how
  /// large they tend to get.
  static const cacheNames = <String>{
    'node_modules',
    '.venv',
    'venv',
    'target',
    'vendor',
    '.gradle',
    '.next',
    '.nuxt',
    '.turbo',
    '.pnpm-store',
    '__pycache__',
    'dist',
    'build',
    '.dart_tool',
    'Pods',
  };

  final ExclusionService? exclusions;
  OrphanCachesService({this.exclusions});

  Future<List<OrphanCache>> scan({
    int maxDepth = 4,
    void Function(String currentPath)? onProgress,
  }) async {
    await exclusions?.readAll();
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return const [];
    final roots = <String>[
      '$home/Documents',
      '$home/Developer',
      '$home/code',
      '$home/Code',
      '$home/Projects',
      '$home/projects',
      '$home/src',
      '$home/repos',
      '$home/work',
      '$home/dev',
      '$home/Desktop',
    ];
    final out = <OrphanCache>[];
    final visited = <String>{};

    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      if (visited.contains(root)) continue;
      visited.add(root);
      await _walk(dir, 0, maxDepth, out, onProgress);
    }
    out.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    return out;
  }

  Future<void> _walk(
    Directory dir,
    int depth,
    int maxDepth,
    List<OrphanCache> sink,
    void Function(String currentPath)? onProgress,
  ) async {
    if (depth > maxDepth) return;
    if (exclusions?.matchesAnySync(dir.path) ?? false) return;
    onProgress?.call(dir.path);

    List<FileSystemEntity> children;
    try {
      children = await dir.list(followLinks: false).toList();
    } catch (_) {
      return;
    }

    // Bucket the children. If any are cache dirs, capture them and skip
    // descending into them. Then recurse into the rest.
    final caches = <Directory>[];
    final subdirs = <Directory>[];
    for (final c in children) {
      if (c is! Directory) continue;
      final name = _basename(c.path);
      if (cacheNames.contains(name)) {
        caches.add(c);
      } else if (!name.startsWith('.') ||
          name == '.venv' ||
          name == '.dart_tool') {
        // Skip most hidden dirs (.git, .DS_Store, .vscode) but allow a
        // couple we know are interesting at deeper levels.
        subdirs.add(c);
      }
    }

    for (final cache in caches) {
      final size = await _du(cache.path);
      if (size <= 0) continue;
      final touched = await _newestMtimeIgnoringCaches(dir);
      sink.add(OrphanCache(
        path: cache.path,
        kind: _basename(cache.path),
        projectPath: dir.path,
        sizeBytes: size,
        projectLastTouched: touched,
      ));
    }

    // Don't recurse into a project root once we've found a cache
    // there — its sibling subfolders are usually source, not nested
    // projects with their own caches.
    if (caches.isNotEmpty) return;

    for (final sub in subdirs) {
      await _walk(sub, depth + 1, maxDepth, sink, onProgress);
    }
  }

  Future<DateTime?> _newestMtimeIgnoringCaches(Directory project) async {
    DateTime? newest;
    try {
      await for (final e in project.list(followLinks: false)) {
        final name = _basename(e.path);
        if (cacheNames.contains(name)) continue;
        if (name.startsWith('.')) continue;
        try {
          final stat = await e.stat();
          if (newest == null || stat.modified.isAfter(newest)) {
            newest = stat.modified;
          }
        } catch (_) {/* skip */}
      }
    } catch (_) {/* skip */}
    return newest;
  }

  Future<int> _du(String path) async {
    try {
      final r = await Process.run('du', ['-sk', path]);
      if (r.exitCode != 0) return 0;
      final kb = int.tryParse(r.stdout.toString().split('\t').first) ?? 0;
      return kb * 1024;
    } catch (_) {
      return 0;
    }
  }

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }
}
