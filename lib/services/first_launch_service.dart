import 'dart:io';

/// Tracks first-run gates. Three markers:
///  - intro_seen        → user finished the splash (1-2-3 animation)
///  - tour_seen         → user finished the guided product tour
///  - walkthrough_seen  → user finished the live coachmark walkthrough
///
/// We persist marker files under
/// ~/Library/Application Support/iMaculate/ so we don't depend on
/// shared_preferences for three booleans.
///
/// **Guarantee:** on a Mac that has never run iMaculate, none of those
/// files exist, [needsOnboarding] returns true, and the launch gate in
/// `app.dart` fires the splash → tour → walkthrough flow.
///
/// **Robustness:**
///   • Writes are atomic (tmp file + rename) so a power-cut mid-write
///     doesn't leave a half-written marker that lies "seen=true".
///   • [maybeReset] honours the `IMACULATE_RESET_ONBOARDING` env var so
///     QA / devs can force the flow to re-fire by relaunching with that
///     variable set.
class FirstLaunchService {
  static const _dirName = 'iMaculate';
  static const _introMarker = 'intro_seen';
  static const _tourMarker = 'tour_seen';
  static const _walkthroughMarker = 'walkthrough_seen';

  /// Override the marker directory in tests; falls back to the real
  /// `~/Library/Application Support/iMaculate/` when null.
  final String? overrideDir;

  /// In tests we hand in a synthetic environment instead of relying on
  /// the real process env.
  final Map<String, String> environment;

  FirstLaunchService({this.overrideDir, Map<String, String>? environment})
      : environment = environment ?? Platform.environment;

  String get _dirPath {
    final dir = overrideDir;
    if (dir != null) return dir;
    final home = environment['HOME'] ?? '/tmp';
    return '$home/Library/Application Support/$_dirName';
  }

  File _file(String name) => File('$_dirPath/$name');

  Future<bool> hasSeenIntro() => _exists(_introMarker);
  Future<bool> hasSeenTour() => _exists(_tourMarker);
  Future<bool> hasSeenWalkthrough() => _exists(_walkthroughMarker);

  /// True when *any* gate is unseen — i.e. the user hasn't completed the
  /// full onboarding. The launch flow uses this to decide whether the
  /// next launch is "first run".
  Future<bool> needsOnboarding() async {
    final results = await Future.wait([
      hasSeenIntro(),
      hasSeenTour(),
      hasSeenWalkthrough(),
    ]);
    return results.any((seen) => !seen);
  }

  Future<void> markIntroSeen() => _writeMarker(_introMarker);
  Future<void> markTourSeen() => _writeMarker(_tourMarker);
  Future<void> markWalkthroughSeen() => _writeMarker(_walkthroughMarker);

  /// Backwards-compat alias kept so older callers compile.
  Future<void> markSeen() => markIntroSeen();

  /// Wipes every marker. Used by the "Replay tutorial" button and by
  /// the env-var reset path.
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

  /// If `IMACULATE_RESET_ONBOARDING=1` is set in the process environment
  /// (handy for `IMACULATE_RESET_ONBOARDING=1 open path/to/app`), wipe
  /// every marker before the launch gate reads them. Returns true when
  /// a reset actually happened.
  Future<bool> maybeReset() async {
    final raw = environment['IMACULATE_RESET_ONBOARDING'];
    if (raw == null) return false;
    final on = raw == '1' || raw.toLowerCase() == 'true';
    if (!on) return false;
    await reset();
    return true;
  }

  // ---- Internals ----

  Future<bool> _exists(String name) async {
    try {
      return _file(name).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Atomic write — drop a temp file, then rename. macOS rename is
  /// atomic on the same filesystem, so a partial marker can't claim
  /// "seen=true" after a crash.
  Future<void> _writeMarker(String name) async {
    try {
      final dir = Directory(_dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String();
      final tmp = File('$_dirPath/$name.tmp');
      await tmp.writeAsString(stamp, flush: true);
      await tmp.rename('$_dirPath/$name');
    } catch (_) {
      // Non-fatal — worst case the user re-sees the gate next launch,
      // which is *exactly* the "always run on first instance" behaviour
      // we want. Better to repeat than skip.
    }
  }
}
