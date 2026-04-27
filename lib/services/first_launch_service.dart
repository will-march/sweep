import 'dart:io';

/// Tracks first-run gates. Three markers:
///  - intro_seen        → user finished the splash (1-2-3 animation)
///  - tour_seen         → user finished the guided product tour
///  - walkthrough_seen  → user finished the live coachmark walkthrough
///
/// We persist marker files under
/// ~/Library/Application Support/iMaculate/ so we don't depend on
/// shared_preferences for three booleans.
class FirstLaunchService {
  static const _dirName = 'iMaculate';
  static const _introMarker = 'intro_seen';
  static const _tourMarker = 'tour_seen';
  static const _walkthroughMarker = 'walkthrough_seen';

  File _file(String name) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return File('$home/Library/Application Support/$_dirName/$name');
  }

  Future<bool> hasSeenIntro() async {
    try {
      return _file(_introMarker).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasSeenTour() async {
    try {
      return _file(_tourMarker).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasSeenWalkthrough() async {
    try {
      return _file(_walkthroughMarker).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> markIntroSeen() => _writeMarker(_introMarker);
  Future<void> markTourSeen() => _writeMarker(_tourMarker);
  Future<void> markWalkthroughSeen() => _writeMarker(_walkthroughMarker);

  /// Backwards-compat alias kept so older callers compile until they
  /// migrate to [markIntroSeen]. New code should call the named markers.
  Future<void> markSeen() => markIntroSeen();

  Future<void> _writeMarker(String name) async {
    try {
      final file = _file(name);
      await file.parent.create(recursive: true);
      await file.writeAsString(DateTime.now().toUtc().toIso8601String());
    } catch (_) {
      // Non-fatal — worst case we re-show the intro / tour.
    }
  }

  Future<void> reset() async {
    for (final name in const [
      _introMarker,
      _tourMarker,
      _walkthroughMarker,
    ]) {
      try {
        final f = _file(name);
        if (f.existsSync()) await f.delete();
      } catch (_) {/* non-fatal */}
    }
  }
}
