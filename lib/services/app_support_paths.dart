import 'dart:io';

/// Helpers for ~/Library/Application Support/iMaculate/ — the canonical
/// location for the app's persisted state (history, exclusions, schedule).
/// Centralised so every service writes under the same root.
class AppSupportPaths {
  AppSupportPaths._();

  static const _dirName = 'iMaculate';

  static String get root {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/$_dirName';
  }

  /// Ensures the directory exists. Safe to call repeatedly.
  static Future<Directory> ensureRoot() async {
    final d = Directory(root);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  static String fileFor(String name) => '$root/$name';
}
