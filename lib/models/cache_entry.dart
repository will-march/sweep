import 'dart:io';

import 'cache_target.dart';

class CacheEntry {
  final CacheTarget target;
  final Directory directory;
  final int sizeBytes;

  const CacheEntry({
    required this.target,
    required this.directory,
    required this.sizeBytes,
  });
}
