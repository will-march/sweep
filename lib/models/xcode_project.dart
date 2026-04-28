/// One subfolder of ~/Library/Developer/Xcode/DerivedData. Each
/// represents a single project's incremental build cache; nuking it
/// is safe but forces the next build to be a clean one.
class XcodeProject {
  /// Folder name on disk, e.g. `MyApp-abcd1234efgh`.
  final String folderName;

  /// Absolute path to the folder.
  final String path;

  /// Project name without the Xcode hash suffix, e.g. `MyApp`.
  final String displayName;

  /// Total size of the folder in bytes.
  final int sizeBytes;

  /// Last modification time of the folder. Folders that haven't moved
  /// in months are usually safe to delete.
  final DateTime lastModified;

  const XcodeProject({
    required this.folderName,
    required this.path,
    required this.displayName,
    required this.sizeBytes,
    required this.lastModified,
  });
}
