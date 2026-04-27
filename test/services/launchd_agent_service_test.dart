import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/models/scan_schedule.dart';
import 'package:sweep/services/launchd_agent_service.dart';

void main() {
  late Directory tmp;
  late LaunchdAgentService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sweep_launchd_');
    service = LaunchdAgentService(
      overrideAgentDir: tmp.path,
      overrideExecutable: '/Applications/Sweep.app/Contents/MacOS/Sweep',
      // Stub out launchctl + id so tests don't shell out.
      processRunner: (exe, args) async =>
          ProcessResult(0, 0, '1000', ''),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('isInstalled is false on a fresh dir', () async {
    expect(await service.isInstalled(), isFalse);
  });

  test('plist for daily contains StartCalendarInterval Hour=3 Minute=30',
      () async {
    final xml = service.buildPlist(
      execPath: '/Applications/Sweep.app/Contents/MacOS/Sweep',
      schedule: const ScanSchedule(frequency: ScheduleFrequency.daily),
      logsDir: '/tmp/logs',
    );
    expect(xml, contains('<key>Label</key>'));
    expect(xml, contains('dev.willmarch.sweep.scheduler'));
    expect(xml, contains('--headless'));
    expect(xml, contains('scheduled-job'));
    expect(xml, contains('<key>Hour</key><integer>3</integer>'));
    expect(xml, contains('<key>Minute</key><integer>30</integer>'));
    expect(xml, isNot(contains('<key>Weekday</key>')));
    expect(xml, isNot(contains('<key>Day</key>')));
  });

  test('plist for weekly carries Weekday=0 (Sunday)', () async {
    final xml = service.buildPlist(
      execPath: '/path/to/exec',
      schedule: const ScanSchedule(frequency: ScheduleFrequency.weekly),
      logsDir: '/tmp/logs',
    );
    expect(xml, contains('<key>Weekday</key><integer>0</integer>'));
  });

  test('plist for monthly carries Day=1', () async {
    final xml = service.buildPlist(
      execPath: '/path/to/exec',
      schedule: const ScanSchedule(frequency: ScheduleFrequency.monthly),
      logsDir: '/tmp/logs',
    );
    expect(xml, contains('<key>Day</key><integer>1</integer>'));
  });

  test('plist embeds the executable path the agent should call',
      () async {
    final xml = service.buildPlist(
      execPath: '/Applications/Sweep.app/Contents/MacOS/Sweep',
      schedule: const ScanSchedule(frequency: ScheduleFrequency.daily),
      logsDir: '/tmp/logs',
    );
    expect(
      xml,
      contains(
        '/Applications/Sweep.app/Contents/MacOS/Sweep',
      ),
    );
  });

  test('install writes the plist and isInstalled flips to true',
      () async {
    final r = await service.install(
      const ScanSchedule(frequency: ScheduleFrequency.daily),
    );
    expect(r.ok, isTrue);
    expect(await service.isInstalled(), isTrue);
    final xml = await File(service.plistPath).readAsString();
    expect(xml, contains('dev.willmarch.sweep.scheduler'));
  });

  test('install with frequency=off uninstalls instead', () async {
    await service.install(
      const ScanSchedule(frequency: ScheduleFrequency.daily),
    );
    expect(await service.isInstalled(), isTrue);
    await service.install(ScanSchedule.off);
    expect(await service.isInstalled(), isFalse);
  });

  test('uninstall is idempotent on a fresh dir', () async {
    final r = await service.uninstall();
    expect(r.ok, isTrue);
  });
}
