import 'dart:io';

import 'app_support_paths.dart';

/// Pulls a usable PNG icon out of a macOS `.app` bundle.
///
/// `.app` bundles store their icon as a multi-resolution `.icns` file
/// inside `Contents/Resources/`. We use the system `sips` tool to
/// convert one of those into a fixed-size PNG and cache it under
/// `~/Library/Application Support/Sweep/icon-cache/` keyed by
/// bundle ID (or bundle path hash if there's no ID). Subsequent reads
/// hit the cache instead of re-running sips.
class IconExtractor {
  static const _cacheDirName = 'icon-cache';

  /// Pixel dimension of the cached PNG. macOS app icons render well
  /// at 64×64 on standard Retina; double this for @2x if needed.
  static const _size = 128;

  Future<String> _ensureCacheDir() async {
    final root = await AppSupportPaths.ensureRoot();
    final dir = Directory('${root.path}/$_cacheDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Returns a path to a cached PNG of [bundlePath]'s icon, or null if
  /// extraction fails (binary plist with weird key, missing icon file,
  /// sips error, etc.). A null return is non-fatal — the UI falls
  /// back to a generic glyph.
  Future<String?> extractFor({
    required String bundlePath,
    required String? bundleId,
  }) async {
    try {
      final cacheDir = await _ensureCacheDir();
      final cacheKey = bundleId == null || bundleId.isEmpty
          ? _hashKey(bundlePath)
          : _safe(bundleId);
      final cachePath = '$cacheDir/$cacheKey.png';
      final cached = File(cachePath);
      if (await cached.exists()) return cachePath;

      final iconPath = await _findIcnsPath(bundlePath);
      if (iconPath == null) return null;

      final r = await Process.run('sips', [
        '-s', 'format', 'png',
        '-Z', '$_size',
        iconPath,
        '--out', cachePath,
      ]);
      if (r.exitCode != 0) return null;
      if (!await cached.exists()) return null;
      return cachePath;
    } catch (_) {
      return null;
    }
  }

  /// Walks the bundle's Resources dir for a viable `.icns` file. We
  /// first honour `CFBundleIconFile` from Info.plist (with `.icns`
  /// appended if missing), then fall back to the canonical
  /// `AppIcon.icns`, then to any `.icns` in Resources.
  Future<String?> _findIcnsPath(String bundlePath) async {
    final resources = Directory('$bundlePath/Contents/Resources');
    if (!await resources.exists()) return null;

    final declared = await _readIconKey(bundlePath);
    if (declared != null) {
      final canonical = declared.endsWith('.icns')
          ? declared
          : '$declared.icns';
      final declaredFile = File('${resources.path}/$canonical');
      if (await declaredFile.exists()) return declaredFile.path;
    }

    final fallback = File('${resources.path}/AppIcon.icns');
    if (await fallback.exists()) return fallback.path;

    // Last resort — first .icns we see.
    await for (final entity in resources.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.icns')) {
        return entity.path;
      }
    }
    return null;
  }

  Future<String?> _readIconKey(String bundlePath) async {
    final plist = File('$bundlePath/Contents/Info.plist');
    if (!await plist.exists()) return null;
    try {
      final raw = await plist.readAsBytes();
      final s = String.fromCharCodes(raw);
      // Same naive XML peek we use elsewhere — works for the common
      // case and falls through cleanly on binary plists.
      final value = _extractKey(s, 'CFBundleIconFile') ??
          _extractKey(s, 'CFBundleIconName');
      return value;
    } catch (_) {
      return null;
    }
  }

  String? _extractKey(String s, String key) {
    final tag = '<key>$key</key>';
    final keyIdx = s.indexOf(tag);
    if (keyIdx < 0) return null;
    final after = s.substring(keyIdx + tag.length);
    final start = after.indexOf('<string>');
    if (start < 0) return null;
    final end = after.indexOf('</string>', start);
    if (end < 0) return null;
    return after.substring(start + '<string>'.length, end).trim();
  }

  String _hashKey(String input) {
    var h = 0;
    for (final c in input.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return 'app-$h';
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
