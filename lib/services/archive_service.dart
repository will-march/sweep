import 'dart:convert';
import 'dart:io';

/// One source path bundled into an archive.
class ArchiveItem {
  /// Where the file/dir lived on disk before we archived it.
  final String originalPath;

  /// Where it ended up inside the zip — relative to the zip root.
  final String archiveRelPath;

  /// Total size in bytes (the source's `du -sk` reading at archive time).
  final int sizeBytes;

  const ArchiveItem({
    required this.originalPath,
    required this.archiveRelPath,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'originalPath': originalPath,
        'archiveRelPath': archiveRelPath,
        'sizeBytes': sizeBytes,
      };

  factory ArchiveItem.fromJson(Map<String, dynamic> j) => ArchiveItem(
        originalPath: j['originalPath'] as String,
        archiveRelPath: j['archiveRelPath'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
      );
}

/// Compresses one or more source paths into a single zip archive,
/// preserving macOS metadata via the `ditto` shell tool. The archive
/// layout is:
///
/// ```
/// archive.zip
/// ├── manifest.json     # original-path map and version stamp
/// └── items/
///     ├── 0/<basename>
///     ├── 1/<basename>
///     └── ...
/// ```
///
/// `ditto -c -k --sequesterRsrc` is the right tool here — `zip(1)`
/// loses extended attributes and resource forks, which would brick a
/// signed `.app` bundle on restore. `ditto -x -k` reverses it.
class ArchiveService {
  /// Compress [sourcePaths] into [archivePath]. Returns the per-item
  /// records suitable for storing in the restore log.
  Future<List<ArchiveItem>> compress({
    required List<String> sourcePaths,
    required String archivePath,
  }) async {
    final tmp = await Directory.systemTemp
        .createTemp('sweep-archive-staging-');
    try {
      final itemsDir = Directory('${tmp.path}/items');
      await itemsDir.create(recursive: true);
      final items = <ArchiveItem>[];

      for (var i = 0; i < sourcePaths.length; i++) {
        final src = sourcePaths[i];
        final basename = _basename(src);
        final destDir = Directory('${itemsDir.path}/$i');
        await destDir.create();
        final dest = '${destDir.path}/$basename';
        // ditto src dest preserves bundles, resource forks, xattrs, ACLs.
        final r = await Process.run('ditto', [src, dest]);
        if (r.exitCode != 0) {
          throw Exception(
            'ditto failed copying $src into staging: ${r.stderr}',
          );
        }
        items.add(ArchiveItem(
          originalPath: src,
          archiveRelPath: 'items/$i/$basename',
          sizeBytes: await _measure(dest),
        ));
      }

      // manifest.json sits at the zip root next to items/.
      final manifest = File('${tmp.path}/manifest.json');
      await manifest.writeAsString(jsonEncode({
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      }));

      // ditto -c -k --sequesterRsrc <staging> <archive>: zip the staging
      // *contents* (no parent wrap) into archivePath.
      final zip = await Process.run('ditto', [
        '-c',
        '-k',
        '--sequesterRsrc',
        tmp.path,
        archivePath,
      ]);
      if (zip.exitCode != 0) {
        throw Exception('ditto archive failed: ${zip.stderr}');
      }
      return items;
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {/* non-fatal */}
    }
  }

  /// Extract [archivePath] into [stagingDir] (created if missing).
  Future<void> extract({
    required String archivePath,
    required String stagingDir,
  }) async {
    final dir = Directory(stagingDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final r = await Process.run('ditto', [
      '-x',
      '-k',
      archivePath,
      stagingDir,
    ]);
    if (r.exitCode != 0) {
      throw Exception('ditto extract failed: ${r.stderr}');
    }
  }

  /// Read manifest.json from an extracted staging dir. Throws if
  /// manifest is missing or unreadable.
  Future<List<ArchiveItem>> readManifest(String stagingDir) async {
    final file = File('$stagingDir/manifest.json');
    if (!await file.exists()) {
      throw Exception('manifest.json missing in $stagingDir');
    }
    final raw = await file.readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['items'] as List<dynamic>;
    return list
        .map((e) => ArchiveItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> _measure(String path) async {
    try {
      final r = await Process.run('du', ['-sk', path]);
      if (r.exitCode != 0) return 0;
      final kb = int.tryParse(r.stdout.toString().split('\t').first) ?? 0;
      return kb * 1024;
    } catch (_) {
      return 0;
    }
  }

  String _basename(String path) {
    final cleaned =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = cleaned.lastIndexOf('/');
    return i < 0 ? cleaned : cleaned.substring(i + 1);
  }
}
