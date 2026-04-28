import 'dart:io';

import '../models/xcode_project.dart';

/// Lists the per-project subfolders inside
/// ~/Library/Developer/Xcode/DerivedData. Xcode names each folder
/// `<ProjectName>-<hash>` and writes incremental build artefacts into
/// it; deleting a single folder forces the next `xcodebuild` of that
/// one project to start from scratch but doesn't affect others.
///
/// We deliberately skip the shared `ModuleCache.noindex` and
/// `Logs/` siblings — those are global, not per-project, and emptying
/// them via this UI would surprise the user.
class XcodeDerivedDataService {
  static String get rootPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Developer/Xcode/DerivedData';
  }

  Future<List<XcodeProject>> scan() async {
    final root = Directory(rootPath);
    if (!await root.exists()) return const [];

    final out = <XcodeProject>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = _basename(entity.path);
      // Shared/global Xcode caches — not per-project, skip.
      if (name == 'ModuleCache.noindex') continue;
      if (name == 'Logs') continue;
      if (name.startsWith('.')) continue;

      final size = await _du(entity.path);
      final mtime = await _mtime(entity);
      out.add(XcodeProject(
        folderName: name,
        path: entity.path,
        displayName: _stripHashSuffix(name),
        sizeBytes: size,
        lastModified: mtime,
      ));
    }
    out.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    return out;
  }

  /// Xcode appends a `-<28-char hash>` suffix to the project name.
  /// Strip it so the UI shows a friendly project name. We don't touch
  /// the path itself.
  String _stripHashSuffix(String folder) {
    final i = folder.lastIndexOf('-');
    if (i < 0) return folder;
    final suffix = folder.substring(i + 1);
    if (suffix.length >= 20 &&
        RegExp(r'^[a-zA-Z0-9]+$').hasMatch(suffix)) {
      return folder.substring(0, i);
    }
    return folder;
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

  Future<DateTime> _mtime(Directory d) async {
    try {
      final s = await d.stat();
      return s.modified;
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }
}
