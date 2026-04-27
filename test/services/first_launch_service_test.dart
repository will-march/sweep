import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweep/services/first_launch_service.dart';

void main() {
  late Directory tmp;
  late FirstLaunchService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sweep_first_');
    service = FirstLaunchService(overrideDir: tmp.path, environment: const {});
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('first-install behaviour', () {
    test(
      'every gate is unseen when no markers exist',
      () async {
        expect(await service.hasSeenIntro(), isFalse);
        expect(await service.hasSeenTour(), isFalse);
        expect(await service.hasSeenWalkthrough(), isFalse);
        expect(
          await service.needsOnboarding(),
          isTrue,
          reason: 'a fresh install must always need the full onboarding',
        );
      },
    );

    test('needsOnboarding stays true until ALL markers are written',
        () async {
      await service.markIntroSeen();
      expect(await service.needsOnboarding(), isTrue);
      await service.markTourSeen();
      expect(await service.needsOnboarding(), isTrue);
      await service.markWalkthroughSeen();
      expect(await service.needsOnboarding(), isFalse);
    });
  });

  group('marker durability', () {
    test('writes round-trip across new service instances', () async {
      await service.markIntroSeen();
      final reread = FirstLaunchService(
        overrideDir: tmp.path,
        environment: const {},
      );
      expect(await reread.hasSeenIntro(), isTrue);
    });

    test('writes are atomic — no .tmp file is left behind', () async {
      await service.markIntroSeen();
      final entries = tmp.listSync().map((e) => e.path).toList();
      expect(entries, hasLength(1));
      expect(entries.single, endsWith('intro_seen'));
    });

    test('reset wipes every marker and re-fires the gate', () async {
      await service.markIntroSeen();
      await service.markTourSeen();
      await service.markWalkthroughSeen();
      expect(await service.needsOnboarding(), isFalse);
      await service.reset();
      expect(await service.needsOnboarding(), isTrue);
    });
  });

  group('SWEEP_RESET_ONBOARDING env var', () {
    test('maybeReset is a no-op when the var is unset', () async {
      await service.markIntroSeen();
      final didReset = await service.maybeReset();
      expect(didReset, isFalse);
      expect(await service.hasSeenIntro(), isTrue);
    });

    test('maybeReset wipes markers when the var is "1"', () async {
      final reset = FirstLaunchService(
        overrideDir: tmp.path,
        environment: const {'SWEEP_RESET_ONBOARDING': '1'},
      );
      await reset.markIntroSeen();
      await reset.markTourSeen();
      final didReset = await reset.maybeReset();
      expect(didReset, isTrue);
      expect(await reset.hasSeenIntro(), isFalse);
      expect(await reset.hasSeenTour(), isFalse);
    });

    test('maybeReset accepts case-insensitive "true"', () async {
      final reset = FirstLaunchService(
        overrideDir: tmp.path,
        environment: const {'SWEEP_RESET_ONBOARDING': 'TRUE'},
      );
      await reset.markIntroSeen();
      expect(await reset.maybeReset(), isTrue);
      expect(await reset.hasSeenIntro(), isFalse);
    });

    test('maybeReset ignores other values like "0"', () async {
      final reset = FirstLaunchService(
        overrideDir: tmp.path,
        environment: const {'SWEEP_RESET_ONBOARDING': '0'},
      );
      await reset.markIntroSeen();
      expect(await reset.maybeReset(), isFalse);
      expect(await reset.hasSeenIntro(), isTrue);
    });
  });
}
