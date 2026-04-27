import 'dart:io';

import '../models/installed_app.dart';
import 'icon_extractor.dart';

/// Walks `/Applications` (and `~/Applications` if present) and returns
/// every `.app` bundle plus its associated user-scope leftovers
/// (Application Support, Caches, Logs, Preferences, Containers).
///
/// Leftover discovery is *prefix-based on bundle ID*, not heuristic
/// fuzzy matching. We only nominate a leftover if its name matches
/// the bundle's ID or the app's name exactly. False positives in an
/// uninstaller are catastrophic — we'd rather miss a 2 MB cache than
/// trash an unrelated app's data.
class InstalledAppsService {
  final IconExtractor _icons = IconExtractor();

  Future<List<InstalledApp>> scan() async {
    final home = Platform.environment['HOME'] ?? '';
    final dirs = <String>['/Applications', '$home/Applications'];

    final out = <InstalledApp>[];
    for (final dir in dirs) {
      final d = Directory(dir);
      if (!await d.exists()) continue;
      await for (final entity in d.list(followLinks: false)) {
        if (entity is! Directory) continue;
        if (!entity.path.endsWith('.app')) continue;
        final app = await _readApp(entity, home);
        if (app != null) out.add(app);
      }
    }
    out.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return out;
  }

  Future<InstalledApp?> _readApp(Directory bundle, String home) async {
    try {
      final infoPlist = File('${bundle.path}/Contents/Info.plist');
      String? bundleId;
      String name = bundle.uri.pathSegments
              .where((p) => p.isNotEmpty)
              .last
              .replaceAll('.app', '');
      if (await infoPlist.exists()) {
        final raw = await infoPlist.readAsBytes();
        bundleId = _extractKey(raw, 'CFBundleIdentifier');
        final cfName = _extractKey(raw, 'CFBundleName');
        if (cfName != null && cfName.isNotEmpty) name = cfName;
      }
      final size = await _du(bundle.path);
      final leftovers = await _findLeftovers(home, bundleId, name);
      final iconPath = await _icons.extractFor(
        bundlePath: bundle.path,
        bundleId: bundleId,
      );
      return InstalledApp(
        name: name,
        bundleId: bundleId,
        bundlePath: bundle.path,
        bundleSize: size,
        leftovers: leftovers,
        iconPath: iconPath,
      );
    } catch (_) {
      return null;
    }
  }

  /// Naive Info.plist key reader — Info.plist is usually XML on macOS,
  /// but some bundles ship binary plists. We read the file as a string
  /// (latin1-permissive) and pull the first `<string>` after the key.
  /// For binary plists this falls through to null, which is fine — the
  /// caller has a name fallback and we still surface the bundle.
  String? _extractKey(List<int> raw, String key) {
    final s = String.fromCharCodes(raw);
    final keyTag = '<key>$key</key>';
    final keyIdx = s.indexOf(keyTag);
    if (keyIdx < 0) return null;
    final after = s.substring(keyIdx + keyTag.length);
    final start = after.indexOf('<string>');
    if (start < 0) return null;
    final end = after.indexOf('</string>', start);
    if (end < 0) return null;
    return after.substring(start + '<string>'.length, end).trim();
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

  Future<List<AppLeftover>> _findLeftovers(
    String home,
    String? bundleId,
    String name,
  ) async {
    if (home.isEmpty) return const [];
    final candidates = <(String label, String path)>[
      ('Application Support', '$home/Library/Application Support/$name'),
      if (bundleId != null) ...[
        ('Caches', '$home/Library/Caches/$bundleId'),
        ('Preferences', '$home/Library/Preferences/$bundleId.plist'),
        ('Containers', '$home/Library/Containers/$bundleId'),
        ('Group Containers',
            '$home/Library/Group Containers/$bundleId'),
        ('Saved State',
            '$home/Library/Saved Application State/$bundleId.savedState'),
        ('HTTPStorages',
            '$home/Library/HTTPStorages/$bundleId'),
        ('WebKit', '$home/Library/WebKit/$bundleId'),
      ],
      ('Logs', '$home/Library/Logs/$name'),
    ];
    final out = <AppLeftover>[];
    for (final (label, path) in candidates) {
      final exists = await FileSystemEntity.isDirectory(path) ||
          await File(path).exists();
      if (!exists) continue;
      final size = await _du(path);
      if (size <= 0) continue;
      out.add(AppLeftover(label: label, path: path, size: size));
    }
    return out;
  }
}
