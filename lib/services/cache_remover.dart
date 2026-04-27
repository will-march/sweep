import 'dart:io';

import '../models/cache_target.dart';

class CacheRemover {
  final bool privileged;
  CacheRemover({required this.privileged});

  /// Empty the directory's contents but keep the directory itself —
  /// applications often assume their cache parent exists.
  Future<void> empty(Directory dir, RiskLevel risk) async {
    if (privileged && risk == RiskLevel.higher) {
      await _privilegedEmpty(dir);
    } else {
      await _userEmpty(dir);
    }
  }

  Future<void> _userEmpty(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      try {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else {
          await entity.delete();
        }
      } catch (_) {
        // Skip entries we can't remove; partial cleanup is preferable to abort.
      }
    }
  }

  /// Privileged path goes through osascript with admin privileges.
  /// `quoted form of` makes shell tokenisation safe; the AppleScript string
  /// literal escapes \ and " so paths with metacharacters are still safe.
  Future<void> _privilegedEmpty(Directory dir) async {
    final escaped = dir.path.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final script =
        'do shell script "/usr/bin/find " & quoted form of "$escaped"'
        ' & " -mindepth 1 -delete" with administrator privileges';
    final r = await Process.run('osascript', ['-e', script]);
    if (r.exitCode != 0) {
      final err = r.stderr.toString().trim();
      throw Exception(
        err.isEmpty ? 'osascript exited with code ${r.exitCode}' : err,
      );
    }
  }
}
