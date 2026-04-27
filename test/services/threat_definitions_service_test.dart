import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/services/threat_definitions_service.dart';

void main() {
  late Directory tmp;
  late ThreatDefinitionsService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sweep_threats_');
    service = ThreatDefinitionsService(overrideDir: tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('read returns empty when no file exists', () async {
    final d = await service.read();
    expect(d.signatures, isEmpty);
    expect(d.updatedAt, isNull);
  });

  test('read parses a previously written definitions file', () async {
    final json = jsonEncode({
      'updatedAt': '2026-04-27T10:00:00.000Z',
      'source': 'test',
      'signatures': [
        {
          'sha256':
              'abc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abcd',
          'name': 'TestFamily',
          'source': 'unit-test',
        }
      ],
    });
    await File('${tmp.path}/threats.json').writeAsString(json);
    final d = await service.read();
    expect(d.signatures, hasLength(1));
    expect(d.signatures.single.name, 'TestFamily');
    expect(d.lookup('ABC123ABC123ABC123ABC123ABC123ABC123ABC123ABC123ABC123ABC123ABCD'),
        isNotNull,
        reason: 'lookups must be case-insensitive on the digest');
  });

  test('read tolerates a corrupt definitions file', () async {
    await File('${tmp.path}/threats.json')
        .writeAsString('{ this is not json');
    final d = await service.read();
    expect(d.signatures, isEmpty);
  });

  test('lookup returns null for unknown digests', () async {
    final json = jsonEncode({
      'updatedAt': '2026-04-27T10:00:00.000Z',
      'source': 'test',
      'signatures': const [],
    });
    await File('${tmp.path}/threats.json').writeAsString(json);
    final d = await service.read();
    expect(d.lookup('deadbeef'), isNull);
  });
}
