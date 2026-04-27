import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/models/scan_schedule.dart';
import 'package:sweep/services/schedule_service.dart';

void main() {
  late Directory tmp;
  late ScheduleService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sweep_sched_');
    service = ScheduleService(overridePath: '${tmp.path}/schedule.json');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('default is off when no file exists', () async {
    final s = await service.read();
    expect(s.frequency, ScheduleFrequency.off);
    expect(s.lastRunAt, isNull);
  });

  test('write + read round-trips', () async {
    final s = ScanSchedule(
      frequency: ScheduleFrequency.weekly,
      lastRunAt: DateTime.utc(2026, 4, 1, 12),
    );
    await service.write(s);
    final read = await service.read();
    expect(read.frequency, ScheduleFrequency.weekly);
    expect(read.lastRunAt, DateTime.utc(2026, 4, 1, 12));
  });

  test('isDue returns false for off', () {
    expect(ScanSchedule.off.isDue(DateTime(2026, 1, 1)), isFalse);
  });

  test('isDue returns true when never run', () {
    const s = ScanSchedule(frequency: ScheduleFrequency.daily);
    expect(s.isDue(DateTime.now()), isTrue);
  });

  test('isDue waits for the period to elapse', () {
    final last = DateTime(2026, 4, 1, 12);
    final s = ScanSchedule(
      frequency: ScheduleFrequency.daily,
      lastRunAt: last,
    );
    expect(s.isDue(last.add(const Duration(hours: 12))), isFalse);
    expect(s.isDue(last.add(const Duration(days: 1, hours: 1))), isTrue);
  });

  test('markRanNow updates lastRunAt', () async {
    await service.write(const ScanSchedule(
      frequency: ScheduleFrequency.weekly,
    ));
    final before = DateTime.now();
    await service.markRanNow();
    final s = await service.read();
    expect(s.frequency, ScheduleFrequency.weekly);
    expect(
      s.lastRunAt!.isAtSameMomentAs(before) || s.lastRunAt!.isAfter(before),
      isTrue,
    );
  });
}
