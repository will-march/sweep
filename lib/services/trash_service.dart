import 'dart:io';

/// Moves filesystem entries to the macOS Trash via Finder, or — when asked —
/// permanently removes them with elevated privileges. Trash is the default
/// because it's recoverable; permanent delete must be opted into.
class TrashService {
  /// Moves [path] to the user's Trash. The directory or file remains
  /// recoverable from Finder until the user empties the Trash.
  Future<void> moveToTrash(String path) async {
    final escaped = _escapeForAppleScript(path);
    final script =
        'tell application "Finder" to delete (POSIX file "$escaped" as alias)';
    final r = await Process.run('osascript', ['-e', script]);
    if (r.exitCode != 0) {
      final err = r.stderr.toString().trim();
      throw Exception(
        err.isEmpty ? 'osascript exited with ${r.exitCode}' : err,
      );
    }
  }

  /// Permanently removes [path]. Uses /bin/rm under admin privileges so
  /// SIP-protected and system locations can be wiped — the caller is expected
  /// to have already obtained admin auth.
  Future<void> permanentlyDelete({
    required String path,
    required bool isDirectory,
  }) async {
    final escaped = _escapeForAppleScript(path);
    final cmd = isDirectory ? '/bin/rm -rf -- ' : '/bin/rm -- ';
    final script =
        'do shell script "$cmd" & quoted form of "$escaped" with administrator privileges';
    final r = await Process.run('osascript', ['-e', script]);
    if (r.exitCode != 0) {
      final err = r.stderr.toString().trim();
      throw Exception(
        err.isEmpty ? 'osascript exited with ${r.exitCode}' : err,
      );
    }
  }

  String _escapeForAppleScript(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
