import 'dart:io';

import '../models/launch_item.dart';

/// Walks the standard macOS launchd plist directories and returns
/// every `.plist` it finds with a coarse parse of Label /
/// ProgramArguments / RunAtLoad. We deliberately *don't* run
/// `launchctl print` — that requires elevated privileges for daemons
/// and isn't strictly necessary for "show me what's set to run". The
/// plists are the source of truth for "do I exist on this machine".
///
/// Suspicion heuristic ([_suspiciousProgramPath]) flags any program
/// whose executable lives outside the well-known good locations
/// (`/Applications`, `/System`, `/usr`, `/Library`, `/opt/homebrew`,
/// `~/Library/Application Support`, well-known dev caches). False
/// positives are fine — the UI surfaces this as a soft warning, not an
/// auto-remove.
class LaunchItemsService {
  Future<List<LaunchItem>> scan() async {
    final home = Platform.environment['HOME'] ?? '';
    final out = <LaunchItem>[];
    final dirs = <(String, LaunchScope)>[
      if (home.isNotEmpty) ('$home/Library/LaunchAgents', LaunchScope.userAgent),
      ('/Library/LaunchAgents', LaunchScope.globalAgent),
      ('/Library/LaunchDaemons', LaunchScope.globalDaemon),
      // /System/Library/LaunchAgents and /System/Library/LaunchDaemons
      // are Apple-managed; we deliberately skip them.
    ];
    for (final (path, scope) in dirs) {
      final dir = Directory(path);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.plist')) continue;
          final item = await _readPlist(entity, scope);
          if (item != null) out.add(item);
        }
      } catch (_) {/* unreadable dir — skip */}
    }
    out.sort((a, b) {
      // Suspicious first, then by scope severity (daemon > global > user),
      // then alphabetical.
      if (a.suspicious != b.suspicious) {
        return a.suspicious ? -1 : 1;
      }
      final scopeRank = {
        LaunchScope.globalDaemon: 0,
        LaunchScope.globalAgent: 1,
        LaunchScope.userAgent: 2,
      };
      final byScope =
          scopeRank[a.scope]!.compareTo(scopeRank[b.scope]!);
      if (byScope != 0) return byScope;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return out;
  }

  Future<LaunchItem?> _readPlist(File f, LaunchScope scope) async {
    try {
      final raw = await f.readAsBytes();
      final s = String.fromCharCodes(raw);
      final labelFromPlist = _string(s, 'Label');
      final filenameLabel = _basename(f.path).replaceAll('.plist', '');
      final label = labelFromPlist?.isNotEmpty == true
          ? labelFromPlist!
          : filenameLabel;
      final program =
          _firstProgramArgument(s) ?? _string(s, 'Program');
      final runAtLoad = _boolKey(s, 'RunAtLoad');
      final size = await f.length();
      final suspicious = _isSuspicious(label, program);
      return LaunchItem(
        plistPath: f.path,
        label: label,
        program: program,
        runAtLoad: runAtLoad,
        scope: scope,
        suspicious: suspicious,
        sizeBytes: size,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------- naive XML plist peeks -------------

  String? _string(String s, String key) {
    final tag = '<key>$key</key>';
    final i = s.indexOf(tag);
    if (i < 0) return null;
    final after = s.substring(i + tag.length);
    final start = after.indexOf('<string>');
    if (start < 0) return null;
    final end = after.indexOf('</string>', start);
    if (end < 0) return null;
    return after.substring(start + '<string>'.length, end).trim();
  }

  bool _boolKey(String s, String key) {
    final tag = '<key>$key</key>';
    final i = s.indexOf(tag);
    if (i < 0) return false;
    // Look at the next ~80 chars for <true/> or <false/>.
    final after = s.substring(i + tag.length, (i + 200).clamp(0, s.length));
    return after.contains('<true/>') || after.contains('<true />');
  }

  String? _firstProgramArgument(String s) {
    final tag = '<key>ProgramArguments</key>';
    final i = s.indexOf(tag);
    if (i < 0) return null;
    final arrayStart = s.indexOf('<array>', i);
    if (arrayStart < 0) return null;
    final arrayEnd = s.indexOf('</array>', arrayStart);
    if (arrayEnd < 0) return null;
    final block = s.substring(arrayStart, arrayEnd);
    final firstStart = block.indexOf('<string>');
    if (firstStart < 0) return null;
    final firstEnd = block.indexOf('</string>', firstStart);
    if (firstEnd < 0) return null;
    return block
        .substring(firstStart + '<string>'.length, firstEnd)
        .trim();
  }

  // ------------- suspicion heuristic -------------

  bool _isSuspicious(String label, String? program) {
    final lower = label.toLowerCase();
    // Known adware / nuisance families on macOS.
    const knownBad = [
      'genieo',
      'mackeeper',
      'bundlore',
      'shlayer',
      'silverlight',
      'macsearch',
      'macsrch',
      'cleanmymac', // not malware but commonly impersonated
      'installmac',
      'searchmenu',
      'searchmine',
      'safefinder',
      'omnikeeper',
    ];
    if (knownBad.any(lower.contains)) return true;
    if (program == null) return false;
    return _suspiciousProgramPath(program);
  }

  bool _suspiciousProgramPath(String path) {
    if (path.isEmpty) return false;
    // Anything that runs a shell with hardcoded inline scripts is
    // worth flagging. So is anything in /tmp.
    if (path.startsWith('/tmp/')) return true;
    if (path.startsWith('/var/tmp/')) return true;
    if (path.contains('curl ') ||
        path.contains('wget ') ||
        path.contains('| sh') ||
        path.contains('| bash')) {
      return true;
    }
    final goodPrefixes = <String>[
      '/Applications/',
      '/System/',
      '/usr/',
      '/Library/Application Support/',
      '/Library/PrivilegedHelperTools/',
      '/opt/homebrew/',
      '/opt/local/',
      '/Library/Frameworks/',
      '${Platform.environment['HOME'] ?? ''}/Library/Application Support/',
      '${Platform.environment['HOME'] ?? ''}/.cargo/',
      '${Platform.environment['HOME'] ?? ''}/.npm/',
    ];
    return !goodPrefixes.any(path.startsWith);
  }

  String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }
}
