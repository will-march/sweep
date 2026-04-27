import 'dart:convert';
import 'dart:io';

import 'app_support_paths.dart';

/// One signature row stored in our local definitions database.
class ThreatSignature {
  /// SHA-256 hex digest, lower-case. Match key.
  final String sha256;

  /// Human-readable family / signature name. Empty when the upstream
  /// feed didn't provide one.
  final String name;

  /// Signature source ("MalwareBazaar", "manual", etc.).
  final String source;

  const ThreatSignature({
    required this.sha256,
    required this.name,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'sha256': sha256,
        'name': name,
        'source': source,
      };

  factory ThreatSignature.fromJson(Map<String, dynamic> j) =>
      ThreatSignature(
        sha256: j['sha256'] as String,
        name: (j['name'] as String?) ?? '',
        source: (j['source'] as String?) ?? '',
      );
}

/// In-memory definitions snapshot — what the scanner reads.
class ThreatDefinitions {
  final DateTime? updatedAt;
  final List<ThreatSignature> signatures;
  final Map<String, ThreatSignature> _index;

  ThreatDefinitions({
    required this.updatedAt,
    required this.signatures,
  }) : _index = {for (final s in signatures) s.sha256: s};

  ThreatSignature? lookup(String sha256) =>
      _index[sha256.toLowerCase()];

  static const empty = _EmptyThreatDefinitions();
}

class _EmptyThreatDefinitions implements ThreatDefinitions {
  const _EmptyThreatDefinitions();
  @override
  DateTime? get updatedAt => null;
  @override
  List<ThreatSignature> get signatures => const [];
  @override
  Map<String, ThreatSignature> get _index => const {};
  @override
  ThreatSignature? lookup(String sha256) => null;
}

/// Manages the on-disk threat database at
/// ~/Library/Application Support/iMaculate/security/threats.json.
///
/// **Source:** abuse.ch's MalwareBazaar publishes a daily CSV of
/// recently-seen malware hashes. The "recent" CSV (the last day's
/// submissions) is small (~MB) and updates rapidly. We pull that,
/// filter to macOS-relevant rows, extract SHA-256 + signature name,
/// and persist as JSON so subsequent scans don't need network.
///
/// The CSV format (column order):
///   first_seen_utc, sha256_hash, md5_hash, sha1_hash, reporter,
///   file_name, file_type_guess, mime_type, signature, clamav,
///   vtpercent, imphash, ssdeep, tlsh
///
/// Lines starting with `#` are comments. Each value is double-quoted.
class ThreatDefinitionsService {
  static const _dirName = 'security';
  static const _fileName = 'threats.json';

  /// Default upstream feed. The "csv_recent" feed is the
  /// last-24-hours window; switch to `csv_full.zip` later for the
  /// full corpus.
  static const _feedUrl =
      'https://bazaar.abuse.ch/export/csv/recent/';

  final String? overrideDir;
  ThreatDefinitionsService({this.overrideDir});

  String get _dirPath {
    final dir = overrideDir;
    if (dir != null) return dir;
    return '${AppSupportPaths.root}/$_dirName';
  }

  String get _filePath => '$_dirPath/$_fileName';

  Future<ThreatDefinitions> read() async {
    final f = File(_filePath);
    if (!await f.exists()) return ThreatDefinitions.empty;
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return ThreatDefinitions.empty;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final updated = j['updatedAt'] as String?;
      final list = (j['signatures'] as List<dynamic>)
          .map((e) => ThreatSignature.fromJson(e as Map<String, dynamic>))
          .toList();
      return ThreatDefinitions(
        updatedAt: updated == null ? null : DateTime.tryParse(updated),
        signatures: list,
      );
    } catch (_) {
      return ThreatDefinitions.empty;
    }
  }

  /// Pull the upstream feed and rewrite the local definitions file.
  /// Returns the new in-memory snapshot. Throws on network failure so
  /// the UI can surface a real error message.
  Future<ThreatDefinitions> update() async {
    final dir = Directory(_dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final csv = await _httpGet(_feedUrl);
    final sigs = _parseCsv(csv);

    final stamp = DateTime.now().toUtc();
    final payload = jsonEncode({
      'updatedAt': stamp.toIso8601String(),
      'source': _feedUrl,
      'signatures': sigs.map((s) => s.toJson()).toList(),
    });

    // Atomic write: tmp + rename.
    final tmp = File('$_filePath.tmp');
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(_filePath);

    return ThreatDefinitions(updatedAt: stamp, signatures: sigs);
  }

  Future<String> _httpGet(String url) async {
    final client = HttpClient();
    try {
      client.userAgent = 'iMaculate/1.0 (+macOS open-source cleaner)';
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException(
          'Threat feed returned HTTP ${res.statusCode} for $url',
        );
      }
      final buf = StringBuffer();
      await for (final chunk in res.transform(utf8.decoder)) {
        buf.write(chunk);
      }
      return buf.toString();
    } finally {
      client.close(force: true);
    }
  }

  /// Parse the MalwareBazaar CSV. We extract sha256 (column index 1)
  /// and signature (column index 8). Rows whose `file_type_guess`
  /// (column 6) doesn't look macOS-relevant are dropped to keep the
  /// local DB tight.
  List<ThreatSignature> _parseCsv(String csv) {
    const macTypes = <String>{
      'macho',
      'mach-o',
      'app',
      'dmg',
      'pkg',
      'zip',
    };
    final out = <ThreatSignature>[];
    for (final raw in csv.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;
      final cells = _splitCsvRow(line);
      if (cells.length < 9) continue;
      final sha = cells[1].toLowerCase();
      if (sha.length != 64) continue;
      final fileType = cells[6].toLowerCase();
      // Some CSVs encode "n/a" — keep those too rather than drop hashes
      // we can't classify.
      final macish = fileType.isEmpty ||
          fileType == 'n/a' ||
          macTypes.any(fileType.contains);
      if (!macish) continue;
      final sig = cells[8];
      out.add(ThreatSignature(
        sha256: sha,
        name: sig,
        source: 'MalwareBazaar',
      ));
    }
    return out;
  }

  /// Split a single CSV row honouring `"quoted, fields"`. The
  /// MalwareBazaar feed always quotes — bog-standard CSV.
  List<String> _splitCsvRow(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        // Doubled quote inside a quoted cell = literal.
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
