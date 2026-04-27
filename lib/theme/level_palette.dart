import 'package:flutter/material.dart';

import '../models/cache_target.dart';
import '../models/cleaning_level.dart';
import 'tokens.dart';

/// Aurora level palette — each cleaning level has a full tonal family
/// (30/40/50/80/90/95) harmonized to the seed.
class LevelPalette {
  final Color t30;
  final Color t40;
  final Color t50;
  final Color t80;
  final Color t90;
  final Color t95;
  const LevelPalette({
    required this.t30,
    required this.t40,
    required this.t50,
    required this.t80,
    required this.t90,
    required this.t95,
  });

  /// Tone that reads correctly as the level's accent in the current theme.
  /// Light mode uses t40 (deep); dark mode uses t80 (bright).
  Color accent(Brightness b) => b == Brightness.dark ? t80 : t40;

  /// Tone for "on" text/icons sitting on the accent fill (mirror of accent).
  Color onAccent(Brightness b) => b == Brightness.dark ? t30 : Colors.white;

  /// Quiet container tone — used for subtle level-tinted surfaces (chips,
  /// rings, hero card gradient endpoints).
  Color container(Brightness b) => b == Brightness.dark ? t30 : t95;

  Color onContainer(Brightness b) => b == Brightness.dark ? t90 : t30;
}

const scrubPalette = LevelPalette(
  t30: AuroraTokens.scrub30,
  t40: AuroraTokens.scrub40,
  t50: AuroraTokens.scrub50,
  t80: AuroraTokens.scrub80,
  t90: AuroraTokens.scrub90,
  t95: AuroraTokens.scrub95,
);
const boilPalette = LevelPalette(
  t30: AuroraTokens.boil30,
  t40: AuroraTokens.boil40,
  t50: AuroraTokens.boil50,
  t80: AuroraTokens.boil80,
  t90: AuroraTokens.boil90,
  t95: AuroraTokens.boil95,
);
const sandPalette = LevelPalette(
  t30: AuroraTokens.sand30,
  t40: AuroraTokens.sand40,
  t50: AuroraTokens.sand50,
  t80: AuroraTokens.sand80,
  t90: AuroraTokens.sand90,
  t95: AuroraTokens.sand95,
);
const devPalette = LevelPalette(
  t30: AuroraTokens.dev30,
  t40: AuroraTokens.dev40,
  t50: AuroraTokens.dev50,
  t80: AuroraTokens.dev80,
  t90: AuroraTokens.dev90,
  t95: AuroraTokens.dev95,
);

LevelPalette levelPalette(CleaningLevel level) => switch (level) {
      CleaningLevel.lightScrub => scrubPalette,
      CleaningLevel.boilwash => boilPalette,
      CleaningLevel.sandblast => sandPalette,
      CleaningLevel.development => devPalette,
    };

/// Convenience: the single accent color used across cards / progress bars.
Color levelAccent(CleaningLevel level, [Brightness b = Brightness.light]) =>
    levelPalette(level).accent(b);

/// Risk -> level palette mapping. Safe == Scrub (green), Moderate == Boilwash
/// (amber), Higher == Sandblast (crimson). This keeps risk semantics rendered
/// in the same hue family as the level the risk corresponds to.
LevelPalette riskPalette(RiskLevel risk) => switch (risk) {
      RiskLevel.safe => scrubPalette,
      RiskLevel.moderate => boilPalette,
      RiskLevel.higher => sandPalette,
    };

Color riskAccent(RiskLevel risk, [Brightness b = Brightness.light]) =>
    riskPalette(risk).accent(b);
