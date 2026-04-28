/// A single file flagged by [BigOldFilesService] as both large *and*
/// untouched for a while.
class BigOldFile {
  final String path;
  final int sizeBytes;

  /// Most recent of mtime and atime. We use the latter when available
  /// so files the user reads (but doesn't modify) don't look stale.
  final DateTime lastUsed;

  const BigOldFile({
    required this.path,
    required this.sizeBytes,
    required this.lastUsed,
  });
}
