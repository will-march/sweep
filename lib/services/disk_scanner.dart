import 'dart:async';
import 'dart:io';

import '../models/directory_info.dart';

class ScanProgress {
  /// Path currently being measured (empty when finished).
  final String currentPath;

  /// Number of immediate children whose size has been resolved so far.
  final int done;

  /// Total number of immediate children to measure.
  final int total;

  /// Snapshot of all measured children sorted by size descending.
  final List<DirectoryInfo> entries;

  /// True once every child has been measured.
  final bool finished;

  const ScanProgress({
    required this.currentPath,
    required this.done,
    required this.total,
    required this.entries,
    required this.finished,
  });
}

/// Disk scanner. Walks the immediate children of `basePath` (both directories
/// and files, including dotfiles) and reports each child's recursive size via
/// `du -sk`. Emits a stream of [ScanProgress] events so callers can render
/// live updates as each child resolves.
///
/// `du` is used for both files and directories — it follows the same access
/// rules the running user has, so SIP-protected paths under /System still
/// surface their byte counts (SIP locks writes, not reads). Entries the user
/// truly cannot read return 0.
class DiskScanner {
  /// Maximum number of immediate children to keep in the result.
  final int topN;

  /// Optional pre-loaded set of paths to skip during the scan. Children
  /// matching any prefix are dropped before measurement.
  final Set<String> excludedPaths;

  DiskScanner({this.topN = 200, this.excludedPaths = const {}});

  bool _isExcluded(String p) {
    if (excludedPaths.isEmpty) return false;
    for (final ex in excludedPaths) {
      if (p == ex) return true;
      if (p.startsWith('$ex/')) return true;
    }
    return false;
  }

  Stream<ScanProgress> scan(String basePath) async* {
    var children = await _listChildren(basePath);
    if (excludedPaths.isNotEmpty) {
      children = children.where((c) => !_isExcluded(c.path)).toList();
    }

    final results = <DirectoryInfo>[];

    if (children.isEmpty) {
      yield ScanProgress(
        currentPath: '',
        done: 0,
        total: 0,
        entries: const [],
        finished: true,
      );
      return;
    }

    yield ScanProgress(
      currentPath: children.first.path,
      done: 0,
      total: children.length,
      entries: const [],
      finished: false,
    );

    for (var i = 0; i < children.length; i++) {
      final entity = children[i];
      final isDir = entity is Directory;
      final name = _basename(entity.path);

      // Emit "now scanning X" before doing the work.
      yield ScanProgress(
        currentPath: entity.path,
        done: i,
        total: children.length,
        entries: List.unmodifiable(_topN(results)),
        finished: false,
      );

      final size = await _measure(entity);

      results.add(DirectoryInfo(
        path: entity.path,
        name: name,
        size: size,
        isDirectory: isDir,
      ));

      yield ScanProgress(
        currentPath: entity.path,
        done: i + 1,
        total: children.length,
        entries: List.unmodifiable(_topN(results)),
        finished: false,
      );
    }

    yield ScanProgress(
      currentPath: '',
      done: children.length,
      total: children.length,
      entries: List.unmodifiable(_topN(results)),
      finished: true,
    );
  }

  Future<List<FileSystemEntity>> _listChildren(String basePath) async {
    final out = <FileSystemEntity>[];
    try {
      await for (final e in Directory(basePath).list(followLinks: false)) {
        out.add(e);
      }
    } catch (_) {/* unreadable base dir */}
    // Stable iteration order: alphabetical by basename.
    out.sort((a, b) => _basename(a.path).compareTo(_basename(b.path)));
    return out;
  }

  /// Recursive size in bytes. Uses `du -sk` for both files and directories;
  /// `du` reports allocated KB which is what users care about for "what's
  /// taking space?". Falls back to `File.length()` if `du` isn't available.
  Future<int> _measure(FileSystemEntity entity) async {
    try {
      final r = await Process.run('du', ['-sk', entity.path]);
      // `du` exits non-zero when any sub-entry is unreadable, but still
      // writes the partial total to stdout — so trust stdout regardless of
      // the exit code.
      final stdout = r.stdout.toString();
      if (stdout.isNotEmpty) {
        final firstLine = stdout.split('\n').first;
        final firstField = firstLine.split('\t').first.trim();
        final kb = int.tryParse(firstField);
        if (kb != null) return kb * 1024;
      }
    } catch (_) {/* fall through to length() */}

    if (entity is File) {
      try {
        return await entity.length();
      } catch (_) {/* unreadable */}
    }
    return 0;
  }

  List<DirectoryInfo> _topN(List<DirectoryInfo> entries) {
    final sorted = List<DirectoryInfo>.from(entries)
      ..sort((a, b) => b.size.compareTo(a.size));
    if (sorted.length > topN) sorted.removeRange(topN, sorted.length);
    return sorted;
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i == -1 ? path : path.substring(i + 1);
  }
}
