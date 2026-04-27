import 'dart:io';

/// Tracks whether the intro splash has been shown. We persist a small marker
/// file under ~/Library/Application Support/iMaculate/ so we don't depend on
/// shared_preferences for a single boolean.
class FirstLaunchService {
  static const _dirName = 'iMaculate';
  static const _fileName = 'intro_seen';

  File _markerFile() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return File('$home/Library/Application Support/$_dirName/$_fileName');
  }

  Future<bool> hasSeenIntro() async {
    try {
      return _markerFile().existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final file = _markerFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(DateTime.now().toUtc().toIso8601String());
    } catch (_) {
      // If we can't persist the marker the worst case is the user sees the
      // intro again next launch — non-fatal.
    }
  }

  Future<void> reset() async {
    try {
      final f = _markerFile();
      if (f.existsSync()) await f.delete();
    } catch (_) {/* non-fatal */}
  }
}
