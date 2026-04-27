import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iMaculate/models/clean_event.dart';
import 'package:iMaculate/services/history_service.dart';

void main() {
  late Directory tmp;
  late HistoryService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imaculate_history_');
    service = HistoryService(overridePath: '${tmp.path}/history.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  CleanEvent buildEvent({DateTime? at, int bytes = 1024}) => CleanEvent(
        timestamp: at ?? DateTime.now(),
        mode: 'lightScrub',
        totalBytes: bytes,
        entries: [
          CleanEventEntry(
            path: '/tmp/foo',
            name: 'Foo',
            sizeBytes: bytes,
            disposition: 'permanently_deleted',
          ),
        ],
      );

  test('readAll returns empty when no file exists', () async {
    expect(await service.readAll(), isEmpty);
  });

  test('append persists across reads', () async {
    await service.append(buildEvent(bytes: 4096));
    final read = await service.readAll();
    expect(read, hasLength(1));
    expect(read.first.totalBytes, 4096);
    expect(read.first.entries.first.name, 'Foo');
  });

  test('newest events appear first', () async {
    final earlier = buildEvent(at: DateTime(2026, 1, 1), bytes: 1);
    final later = buildEvent(at: DateTime(2026, 6, 1), bytes: 2);
    await service.append(earlier);
    await service.append(later);
    final read = await service.readAll();
    expect(read.first.totalBytes, 2,
        reason: 'most recent append must come first');
    expect(read.last.totalBytes, 1);
  });

  test('history is capped at maxEntries', () async {
    // Append more than maxEntries to confirm trimming.
    final cap = HistoryService.maxEntries;
    for (var i = 0; i < cap + 5; i++) {
      await service.append(buildEvent(bytes: i));
    }
    final read = await service.readAll();
    expect(read, hasLength(cap));
  });

  test('clear deletes the file', () async {
    await service.append(buildEvent());
    await service.clear();
    expect(await service.readAll(), isEmpty);
  });

  test('corrupt file is treated as empty, not a crash', () async {
    final f = File('${tmp.path}/history.json');
    await f.writeAsString('{ this is not json');
    expect(await service.readAll(), isEmpty);
  });
}
