/// One past cleaning operation, persisted under
/// ~/Library/Application Support/Sweep/history.json.
class CleanEvent {
  /// Wall-clock time the clean finished.
  final DateTime timestamp;

  /// Cleaning mode that triggered this — 'lightScrub', 'boilwash',
  /// 'sandblast', 'development', 'uninstall', 'treemap_trash'. Stored
  /// as a string so adding new modes later doesn't break old history
  /// files.
  final String mode;

  /// Per-target results. Each entry is a row in the cleaner's "Detected
  /// caches" list at the moment of cleaning.
  final List<CleanEventEntry> entries;

  /// Total bytes reclaimed across [entries]. Pre-computed so the History
  /// screen doesn't have to fold every load.
  final int totalBytes;

  /// When this event came from the archive-on-delete pipeline, this
  /// is the [RestoreEntry.id] linking back to the zip in Trash. Null
  /// for in-place empties (cache clean) which aren't recoverable.
  final String? restoreId;

  CleanEvent({
    required this.timestamp,
    required this.mode,
    required this.entries,
    required this.totalBytes,
    this.restoreId,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'mode': mode,
        'totalBytes': totalBytes,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (restoreId != null) 'restoreId': restoreId,
      };

  factory CleanEvent.fromJson(Map<String, dynamic> j) => CleanEvent(
        timestamp: DateTime.parse(j['timestamp'] as String),
        mode: j['mode'] as String,
        totalBytes: (j['totalBytes'] as num).toInt(),
        restoreId: j['restoreId'] as String?,
        entries: (j['entries'] as List<dynamic>)
            .map((e) =>
                CleanEventEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CleanEventEntry {
  final String path;
  final String name;
  final int sizeBytes;

  /// 'trashed' or 'permanently_deleted'. Used by Restore-from-Trash to
  /// know whether anything is recoverable.
  final String disposition;

  CleanEventEntry({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.disposition,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'disposition': disposition,
      };

  factory CleanEventEntry.fromJson(Map<String, dynamic> j) =>
      CleanEventEntry(
        path: j['path'] as String,
        name: j['name'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        disposition: j['disposition'] as String,
      );
}
