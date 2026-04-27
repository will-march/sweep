import 'dart:io';

import '../models/restore_entry.dart';
import 'archive_service.dart';
import 'restore_log.dart';

/// Result of an [ArchiveTrashService.restore] call.
class RestoreResult {
  final List<String> restored;

  /// Failures formatted as `[destination]: [reason]`.
  final List<String> failures;

  /// True when every requested item was restored.
  bool get allSucceeded => failures.isEmpty;

  const RestoreResult({required this.restored, required this.failures});
}

/// "Archive on delete" pipeline.
///
///   1. `compress` source paths into a zip via [ArchiveService] (ditto,
///      preserves macOS bundles + xattrs).
///   2. Move the zip into ~/.Trash so the user has *one* Trash item
///      per operation and can recover via Finder's restore.
///   3. Delete the originals (Dart-side delete first; falls back to
///      Finder Trash for sources we don't have permission to remove
///      directly).
///   4. Append a [RestoreEntry] to the local restore log so the History
///      screen can offer a one-click restore.
///
/// Restore reverses step 1–3: locate the archive in Trash, ditto -x
/// into a temp staging dir, move each item back to its original path.
class ArchiveTrashService {
  final ArchiveService _archive;
  final RestoreLog _log;
  ArchiveTrashService({ArchiveService? archive, RestoreLog? log})
      : _archive = archive ?? ArchiveService(),
        _log = log ?? RestoreLog();

  /// Archive [sourcePaths] into ~/.Trash, delete the originals, and
  /// record the operation. Returns the [RestoreEntry.id] so callers
  /// can attach it to whatever event log they keep (e.g. CleanEvent).
  Future<RestoreEntry> archiveAndTrash({
    required String label,
    required String kind,
    required List<String> sourcePaths,
  }) async {
    if (sourcePaths.isEmpty) {
      throw ArgumentError('archiveAndTrash needs at least one source');
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final filename = _archiveFilename(kind: kind, label: label, id: id);
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) {
      throw Exception('HOME not set — cannot locate ~/.Trash');
    }
    final trashPath = '$home/.Trash/$filename';

    // 1. Stage the archive at a known temp path; compress() handles its
    // own internal staging and emits the zip at this path.
    final stagedArchive = '${Directory.systemTemp.path}/$filename';
    final items = await _archive.compress(
      sourcePaths: sourcePaths,
      archivePath: stagedArchive,
    );

    // 2. Slide the staged zip into ~/.Trash so it shows up as a single
    // recoverable Trash item. If it can't rename (different filesystem),
    // fall back to copy + delete.
    try {
      await File(stagedArchive).rename(trashPath);
    } catch (_) {
      await File(stagedArchive).copy(trashPath);
      try {
        await File(stagedArchive).delete();
      } catch (_) {/* non-fatal */}
    }

    // 3. Best-effort delete of originals. We do NOT abort the operation
    // on a single source failure — the archive is already in Trash, so
    // the user has a recoverable record either way.
    for (final src in sourcePaths) {
      await _bestEffortDelete(src);
    }

    final totalBytes =
        items.fold<int>(0, (acc, it) => acc + it.sizeBytes);
    final entry = RestoreEntry(
      id: id,
      label: label,
      kind: kind,
      timestamp: DateTime.now(),
      archiveTrashPath: trashPath,
      items: items,
      totalBytes: totalBytes,
    );
    await _log.append(entry);
    return entry;
  }

  /// Reverse a previous [archiveAndTrash] call. Looks up the entry,
  /// extracts the archive into a temp staging dir, and moves each item
  /// back to its original path. Refuses to overwrite paths that exist
  /// at restore time — those land in [RestoreResult.failures] for the
  /// caller to surface.
  Future<RestoreResult> restore(String entryId) async {
    final entry = await _log.findById(entryId);
    if (entry == null) {
      return const RestoreResult(
        restored: [],
        failures: ['Restore entry not found in the log.'],
      );
    }
    final archive = File(entry.archiveTrashPath);
    if (!await archive.exists()) {
      return RestoreResult(restored: const [], failures: [
        'Archive missing from Trash — Trash may have been emptied.\n'
            '${entry.archiveTrashPath}',
      ]);
    }
    final staging =
        await Directory.systemTemp.createTemp('imaculate-restore-');
    try {
      await _archive.extract(
        archivePath: entry.archiveTrashPath,
        stagingDir: staging.path,
      );
      final restored = <String>[];
      final failures = <String>[];
      for (final item in entry.items) {
        final src = '${staging.path}/${item.archiveRelPath}';
        final dest = item.originalPath;

        if (await FileSystemEntity.type(dest) !=
            FileSystemEntityType.notFound) {
          failures.add(
            '$dest: a file or folder already exists there — restore '
            'aborted for this item.',
          );
          continue;
        }

        // Make sure the parent dir exists; users can move parents
        // around between archive and restore.
        final parentPath = _parent(dest);
        if (parentPath.isNotEmpty) {
          final parent = Directory(parentPath);
          if (!await parent.exists()) {
            try {
              await parent.create(recursive: true);
            } catch (e) {
              failures
                  .add('$dest: could not create parent dir ($e)');
              continue;
            }
          }
        }

        // ditto src dest preserves the bundle's internals (xattrs etc.)
        // on the way back out.
        final r = await Process.run('ditto', [src, dest]);
        if (r.exitCode == 0) {
          restored.add(dest);
        } else {
          failures.add('$dest: ${r.stderr.toString().trim()}');
        }
      }
      // Remove the entry from the log only if we got everything back —
      // partial restores stay listed so the user can retry the
      // failures.
      if (failures.isEmpty) {
        await _log.remove(entryId);
        try {
          await archive.delete();
        } catch (_) {/* leave it for Trash to handle */}
      }
      return RestoreResult(restored: restored, failures: failures);
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (_) {/* non-fatal */}
    }
  }

  Future<void> _bestEffortDelete(String path) async {
    try {
      final type = await FileSystemEntity.type(path);
      switch (type) {
        case FileSystemEntityType.directory:
          await Directory(path).delete(recursive: true);
        case FileSystemEntityType.file:
        case FileSystemEntityType.link:
          await File(path).delete();
        case FileSystemEntityType.notFound:
          return;
        case FileSystemEntityType.pipe:
        case FileSystemEntityType.unixDomainSock:
          return;
        default:
          return;
      }
    } catch (_) {
      // Permission or busy — fall back to Finder's Trash for that one
      // item. The archive is still in Trash regardless, so the user
      // hasn't lost recoverability.
      await _finderTrash(path);
    }
  }

  Future<void> _finderTrash(String path) async {
    final escaped = path.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final script = 'tell application "Finder" to delete '
        '(POSIX file "$escaped" as alias)';
    try {
      await Process.run('osascript', ['-e', script]);
    } catch (_) {/* swallow — non-fatal */}
  }

  String _archiveFilename({
    required String kind,
    required String label,
    required String id,
  }) {
    final safeLabel = label
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    final clipped = safeLabel.length > 60
        ? safeLabel.substring(0, 60)
        : safeLabel;
    return 'iMaculate-$kind-$clipped-$id.zip';
  }

  String _parent(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    if (i <= 0) return '';
    return clean.substring(0, i);
  }
}
