import 'package:flutter/cupertino.dart';

enum CleaningLevel { lightScrub, boilwash, sandblast, development }

extension CleaningLevelInfo on CleaningLevel {
  String get title => switch (this) {
        CleaningLevel.lightScrub => 'Light Scrub',
        CleaningLevel.boilwash => 'Boilwash',
        CleaningLevel.sandblast => 'Sandblast',
        CleaningLevel.development => 'Development',
      };

  String get subtitle => switch (this) {
        CleaningLevel.lightScrub =>
          'Safe daily cleanup — app caches and logs.',
        CleaningLevel.boilwash =>
          'Deeper cleanup — adds dev caches and system app caches.',
        CleaningLevel.sandblast =>
          'Maximum cleanup — system caches, updates and old backups.',
        CleaningLevel.development =>
          'Developer tooling — Xcode, Docker, npm, gradle and more.',
      };

  IconData get icon => switch (this) {
        CleaningLevel.lightScrub => CupertinoIcons.sparkles,
        CleaningLevel.boilwash => CupertinoIcons.flame_fill,
        CleaningLevel.sandblast => CupertinoIcons.burst_fill,
        CleaningLevel.development => CupertinoIcons.hammer_fill,
      };
}
