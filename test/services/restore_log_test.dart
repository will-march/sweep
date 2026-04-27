import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/models/restore_entry.dart';
import 'package:sweep/services/archive_service.dart';
import 'package:sweep/services/restore_log.dart';

void main() {
  late Directory tmp;
  late RestoreLog log;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sweep_restore_log_');
    log = RestoreLog(overridePath: '${tmp.path}/restore_log.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  RestoreEntry sample({String id = 'e1', String label = 'sample'}) =>
      RestoreEntry(
        id: id,
        label: label,
        kind: 'uninstall',
        timestamp: DateTime.utc(2026, 4, 27, 12),
        archiveTrashPath: '/Users/x/.Trash/Sweep-x-$id.zip',
        items: const [
          ArchiveItem(
            originalPath: '/Applications/Foo.app',
            archiveRelPath: 'items/0/Foo.app',
            sizeBytes: 1024,
          ),
        ],
        totalBytes: 1024,
      );

  test('readAll empty by default', () async {
    expect(await log.readAll(), isEmpty);
  });

  test('append + read round-trips', () async {
    await log.append(sample(id: 'a'));
    final all = await log.readAll();
    expect(all, hasLength(1));
    expect(all.single.id, 'a');
    expect(all.single.items.single.originalPath,
        '/Applications/Foo.app');
  });

  test('newest entries appear first', () async {
    await log.append(sample(id: 'old'));
    await log.append(sample(id: 'new'));
    final all = await log.readAll();
    expect(all.first.id, 'new');
    expect(all.last.id, 'old');
  });

  test('findById returns the right entry or null', () async {
    await log.append(sample(id: 'a'));
    await log.append(sample(id: 'b'));
    expect((await log.findById('b'))!.id, 'b');
    expect(await log.findById('missing'), isNull);
  });

  test('remove drops just that entry', () async {
    await log.append(sample(id: 'a'));
    await log.append(sample(id: 'b'));
    await log.remove('a');
    final all = await log.readAll();
    expect(all.map((e) => e.id), ['b']);
  });

  test('cap of maxEntries enforced', () async {
    for (var i = 0; i < RestoreLog.maxEntries + 4; i++) {
      await log.append(sample(id: 'e$i'));
    }
    final all = await log.readAll();
    expect(all, hasLength(RestoreLog.maxEntries));
  });

  test('corrupt file is treated as empty', () async {
    final f = File('${tmp.path}/restore_log.json');
    await f.writeAsString('{ this is not json');
    expect(await log.readAll(), isEmpty);
  });
}
