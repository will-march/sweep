import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iMaculate/services/exclusion_service.dart';

void main() {
  late Directory tmp;
  late ExclusionService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imaculate_excl_');
    service = ExclusionService(overridePath: '${tmp.path}/exclusions.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('starts empty', () async {
    expect(await service.readAll(), isEmpty);
  });

  test('add persists and is unique', () async {
    await service.add('/tmp/keep');
    await service.add('/tmp/keep'); // dedupes
    expect(await service.readAll(), ['/tmp/keep']);
  });

  test('add normalises trailing slashes', () async {
    await service.add('/tmp/keep/');
    expect(await service.readAll(), ['/tmp/keep']);
  });

  test('remove drops the entry', () async {
    await service.add('/tmp/a');
    await service.add('/tmp/b');
    await service.remove('/tmp/a');
    expect(await service.readAll(), ['/tmp/b']);
  });

  test('matchesAnySync handles exact + prefix', () async {
    await service.add('/Users/a/Documents');
    await service.readAll(); // hydrate cache
    expect(service.matchesAnySync('/Users/a/Documents'), isTrue);
    expect(service.matchesAnySync('/Users/a/Documents/Inner'), isTrue);
    expect(
      service.matchesAnySync('/Users/a/DocumentsExtra'),
      isFalse,
      reason: 'prefix match must require a / boundary',
    );
    expect(service.matchesAnySync('/Users/a'), isFalse);
  });
}
