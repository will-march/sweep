import 'dart:io';

import 'threat_definitions_service.dart';

/// One file flagged by the scanner.
class ThreatHit {
  final String path;
  final ThreatSignature signature;
  final int sizeBytes;
  const ThreatHit({
    required this.path,
    required this.signature,
    required this.sizeBytes,
  });
}

/// Live progress event emitted while [ThreatScanner.scan] runs so the
/// UI can show "now scanning X" without freezing.
class ThreatScanProgress {
  final String currentPath;
  final int filesScanned;
  final int filesPlanned;
  final int hitsCount;
  final List<ThreatHit> hits;
  final bool finished;
  const ThreatScanProgress({
    required this.currentPath,
    required this.filesScanned,
    required this.filesPlanned,
    required this.hitsCount,
    required this.hits,
    required this.finished,
  });
}

/// Walks a target directory and computes SHA-256 for each file via
/// `shasum -a 256`. Each digest is matched against the in-memory
/// [ThreatDefinitions] index. Any match is yielded as a [ThreatHit].
///
/// Compared to a pure-Dart hash loop, `shasum` is meaningfully faster
/// for large files because the OS does the read + streaming; it also
/// keeps memory flat.
class ThreatScanner {
  final ThreatDefinitions definitions;

  /// Skip individual files larger than this. Most macOS malware is
  /// well under this cap; hashing 4 GB Steam game payloads is just
  /// burning user CPU.
  final int maxFileSizeBytes;

  /// Skip these top-level path prefixes — Apple-managed, untrusting
  /// to touch and almost never the source of an infection.
  static const _skipPrefixes = <String>[
    '/System/',
    '/private/var/',
    '/private/etc/',
    '/dev/',
    '/Volumes/Recovery',
  ];

  ThreatScanner({
    required this.definitions,
    this.maxFileSizeBytes = 256 * 1024 * 1024, // 256 MB
  });

  Stream<ThreatScanProgress> scan(List<String> targets) async* {
    if (definitions.signatures.isEmpty) {
      yield const ThreatScanProgress(
        currentPath: '',
        filesScanned: 0,
        filesPlanned: 0,
        hitsCount: 0,
        hits: [],
        finished: true,
      );
      return;
    }

    // First pass: enumerate all candidate files (cheap relative to
    // hashing) so the UI gets a planned-total to drive a progress bar.
    final files = <File>[];
    for (final t in targets) {
      await _collect(t, files);
    }

    final hits = <ThreatHit>[];
    var i = 0;

    yield ThreatScanProgress(
      currentPath: files.isEmpty ? '' : files.first.path,
      filesScanned: 0,
      filesPlanned: files.length,
      hitsCount: 0,
      hits: const [],
      finished: false,
    );

    for (final f in files) {
      i++;
      final size = await _safeLength(f);
      if (size > maxFileSizeBytes) {
        yield ThreatScanProgress(
          currentPath: f.path,
          filesScanned: i,
          filesPlanned: files.length,
          hitsCount: hits.length,
          hits: List.unmodifiable(hits),
          finished: false,
        );
        continue;
      }
      final hash = await _sha256(f.path);
      if (hash != null) {
        final sig = definitions.lookup(hash);
        if (sig != null) {
          hits.add(ThreatHit(
            path: f.path,
            signature: sig,
            sizeBytes: size,
          ));
        }
      }
      // Throttle UI updates — every 25 files keeps the stream
      // responsive without flooding setState.
      if (i % 25 == 0 || i == files.length) {
        yield ThreatScanProgress(
          currentPath: f.path,
          filesScanned: i,
          filesPlanned: files.length,
          hitsCount: hits.length,
          hits: List.unmodifiable(hits),
          finished: false,
        );
      }
    }

    yield ThreatScanProgress(
      currentPath: '',
      filesScanned: i,
      filesPlanned: files.length,
      hitsCount: hits.length,
      hits: List.unmodifiable(hits),
      finished: true,
    );
  }

  Future<void> _collect(String root, List<File> out) async {
    if (_shouldSkip(root)) return;
    final type = await FileSystemEntity.type(root, followLinks: false);
    if (type == FileSystemEntityType.file) {
      out.add(File(root));
      return;
    }
    if (type != FileSystemEntityType.directory) return;
    try {
      await for (final e
          in Directory(root).list(recursive: true, followLinks: false)) {
        if (_shouldSkip(e.path)) continue;
        if (e is File) out.add(e);
      }
    } catch (_) {/* unreadable subtree */}
  }

  bool _shouldSkip(String path) {
    for (final prefix in _skipPrefixes) {
      if (path.startsWith(prefix)) return true;
    }
    return false;
  }

  Future<int> _safeLength(File f) async {
    try {
      return await f.length();
    } catch (_) {
      return 0;
    }
  }

  Future<String?> _sha256(String path) async {
    try {
      // shasum -a 256 -p prints "<digest>  <path>"; we just want the
      // first 64 hex chars.
      final r = await Process.run('shasum', ['-a', '256', '-p', path]);
      if (r.exitCode != 0) return null;
      final out = r.stdout.toString().trim();
      if (out.length < 64) return null;
      return out.substring(0, 64).toLowerCase();
    } catch (_) {
      return null;
    }
  }
}
