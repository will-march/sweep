/// Where on disk a launch item lives. The scope determines who runs
/// it and whether removing it needs admin.
enum LaunchScope {
  userAgent,    // ~/Library/LaunchAgents — runs as the current user
  globalAgent,  // /Library/LaunchAgents — runs as the logged-in user
  globalDaemon, // /Library/LaunchDaemons — runs as root (most powerful)
}

extension LaunchScopeInfo on LaunchScope {
  String get label => switch (this) {
        LaunchScope.userAgent => 'User Agent',
        LaunchScope.globalAgent => 'Global Agent',
        LaunchScope.globalDaemon => 'System Daemon (root)',
      };

  /// Daemon scope is risky to remove blindly — flag it so the UI can
  /// show a warning chip.
  bool get isPrivileged => this == LaunchScope.globalDaemon;
}

/// One launchd `.plist` discovered by [LaunchItemsService].
class LaunchItem {
  /// Absolute path to the plist file.
  final String plistPath;

  /// `Label` from the plist, or the filename without extension if the
  /// label is missing / unreadable.
  final String label;

  /// First entry of `ProgramArguments`, or `Program`, whichever the
  /// plist provided. `null` when neither could be parsed (binary
  /// plist or otherwise).
  final String? program;

  /// `true` when the plist had `RunAtLoad = true` — the most common
  /// "run me at login" knob.
  final bool runAtLoad;

  final LaunchScope scope;

  /// Heuristic suspicion flag — see [LaunchItemsService.isSuspicious].
  final bool suspicious;

  /// File size of the plist itself (rarely useful but cheap to track).
  final int sizeBytes;

  const LaunchItem({
    required this.plistPath,
    required this.label,
    required this.program,
    required this.runAtLoad,
    required this.scope,
    required this.suspicious,
    required this.sizeBytes,
  });
}
