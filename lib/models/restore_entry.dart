import '../services/archive_service.dart';

/// One archived deletion that's still recoverable. Persisted in the
/// restore log JSON file under Application Support.
class RestoreEntry {
  /// Stable id (the timestamp millis at archive time). Used by the
  /// History screen's Restore button to pick the right entry.
  final String id;

  /// Human-readable label — "Uninstall Slack", "Clean Documents", etc.
  /// Shown in the History row when restoration is available.
  final String label;

  /// What kind of operation produced the archive. 'uninstall',
  /// 'treemap_trash', 'cleaner_trash', etc.
  final String kind;

  /// Wall-clock time the archive was created.
  final DateTime timestamp;

  /// Absolute path to the archive within the user's Trash. The archive
  /// stays recoverable until the Trash is emptied.
  final String archiveTrashPath;

  /// Items inside the archive (original paths, archive-relative paths,
  /// sizes). Mirrors the ArchiveItem records embedded in the archive's
  /// manifest.json — duplicated here so we can restore even if the
  /// manifest can't be read.
  final List<ArchiveItem> items;

  /// Total bytes archived. Pre-computed.
  final int totalBytes;

  const RestoreEntry({
    required this.id,
    required this.label,
    required this.kind,
    required this.timestamp,
    required this.archiveTrashPath,
    required this.items,
    required this.totalBytes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind,
        'timestamp': timestamp.toIso8601String(),
        'archiveTrashPath': archiveTrashPath,
        'totalBytes': totalBytes,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory RestoreEntry.fromJson(Map<String, dynamic> j) => RestoreEntry(
        id: j['id'] as String,
        label: j['label'] as String,
        kind: j['kind'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        archiveTrashPath: j['archiveTrashPath'] as String,
        totalBytes: (j['totalBytes'] as num).toInt(),
        items: (j['items'] as List<dynamic>)
            .map((e) =>
                ArchiveItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
