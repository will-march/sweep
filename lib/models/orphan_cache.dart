/// One project-local cache directory found by [OrphanCachesService].
/// `node_modules`, `.venv`, `target/`, `vendor/`, etc.
class OrphanCache {
  /// The cache directory's absolute path.
  final String path;

  /// The cache name (`node_modules`, `.venv`, …) — used for grouping.
  final String kind;

  /// The path containing the cache (i.e. the project root that owns it).
  final String projectPath;

  /// Total size of the cache in bytes.
  final int sizeBytes;

  /// The newest mtime found among the project's *non-cache* files —
  /// roughly "when did the developer last touch this project". Null when
  /// we couldn't read the project dir.
  final DateTime? projectLastTouched;

  const OrphanCache({
    required this.path,
    required this.kind,
    required this.projectPath,
    required this.sizeBytes,
    required this.projectLastTouched,
  });
}
