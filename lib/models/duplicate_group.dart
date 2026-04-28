/// A set of files with identical content (same size + same SHA-256).
class DuplicateGroup {
  final int sizeBytes;
  final String hash;
  final List<String> paths;

  const DuplicateGroup({
    required this.sizeBytes,
    required this.hash,
    required this.paths,
  });

  /// Bytes the user would reclaim by keeping a single copy.
  int get reclaimableBytes => sizeBytes * (paths.length - 1);
}
