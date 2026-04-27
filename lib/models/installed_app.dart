/// One macOS application bundle plus its on-disk leftovers.
class InstalledApp {
  /// Human-readable name from `Info.plist`'s `CFBundleName` (or the
  /// .app's basename if that key is missing).
  final String name;

  /// Reverse-DNS bundle identifier from `CFBundleIdentifier`. Used to
  /// match support files in `~/Library`.
  final String? bundleId;

  /// Absolute path to the .app bundle.
  final String bundlePath;

  /// Bundle size in bytes (the .app itself).
  final int bundleSize;

  /// Associated user-scope leftover files: Application Support, Caches,
  /// Logs, Preferences, Containers, etc. Each one is matched by bundle
  /// ID or app name and is safe to remove on uninstall.
  final List<AppLeftover> leftovers;

  const InstalledApp({
    required this.name,
    required this.bundleId,
    required this.bundlePath,
    required this.bundleSize,
    required this.leftovers,
  });

  int get leftoverBytes =>
      leftovers.fold<int>(0, (acc, e) => acc + e.size);

  int get totalBytes => bundleSize + leftoverBytes;
}

class AppLeftover {
  /// Absolute path of the leftover file or directory.
  final String path;

  /// Short human label — "Caches", "Logs", "Preferences", etc. — for
  /// the UI.
  final String label;

  /// Size in bytes.
  final int size;

  const AppLeftover({
    required this.path,
    required this.label,
    required this.size,
  });
}
