class DirectoryInfo {
  final String path;
  final String name;
  final int size;
  final bool isDirectory;

  const DirectoryInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.isDirectory,
  });
}
