import 'dart:io';

class PermissionService {
  /// Request admin privileges via the macOS auth dialog. Returns true if the
  /// user granted access (the password ticket lasts ~5 minutes for subsequent
  /// `osascript ... with administrator privileges` calls).
  Future<bool> requestRoot() async {
    try {
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "whoami" with administrator privileges',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
