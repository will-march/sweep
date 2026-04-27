enum ScheduleFrequency { off, daily, weekly, monthly }

extension ScheduleFrequencyInfo on ScheduleFrequency {
  String get title => switch (this) {
        ScheduleFrequency.off => 'Off',
        ScheduleFrequency.daily => 'Daily',
        ScheduleFrequency.weekly => 'Weekly',
        ScheduleFrequency.monthly => 'Monthly',
      };

  Duration? get period => switch (this) {
        ScheduleFrequency.off => null,
        ScheduleFrequency.daily => const Duration(days: 1),
        ScheduleFrequency.weekly => const Duration(days: 7),
        ScheduleFrequency.monthly => const Duration(days: 30),
      };
}

/// User's schedule preferences. Each task is opt-in independently —
/// most users want Light Scrub on a cadence but the threat scan
/// quarterly, definitions weekly, etc.
class ScanSchedule {
  /// How often the scheduled job fires.
  final ScheduleFrequency frequency;

  /// Last time the scheduler ran (regardless of which tasks fired).
  final DateTime? lastRunAt;

  /// True when the scheduled job should run Light Scrub.
  final bool runLightScrub;

  /// True when the scheduled job should run the threat scan.
  final bool runThreatScan;

  /// True when the scheduled job should refresh threat definitions
  /// before scanning. Cheap, ~MB download — recommended whenever
  /// runThreatScan is on.
  final bool updateDefinitions;

  /// True when the user has installed our launchd agent so the
  /// scheduled job fires even when the GUI isn't open.
  final bool backgroundAgentInstalled;

  const ScanSchedule({
    required this.frequency,
    this.lastRunAt,
    this.runLightScrub = true,
    this.runThreatScan = false,
    this.updateDefinitions = true,
    this.backgroundAgentInstalled = false,
  });

  static const off = ScanSchedule(frequency: ScheduleFrequency.off);

  ScanSchedule copyWith({
    ScheduleFrequency? frequency,
    DateTime? lastRunAt,
    bool? runLightScrub,
    bool? runThreatScan,
    bool? updateDefinitions,
    bool? backgroundAgentInstalled,
  }) =>
      ScanSchedule(
        frequency: frequency ?? this.frequency,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        runLightScrub: runLightScrub ?? this.runLightScrub,
        runThreatScan: runThreatScan ?? this.runThreatScan,
        updateDefinitions: updateDefinitions ?? this.updateDefinitions,
        backgroundAgentInstalled:
            backgroundAgentInstalled ?? this.backgroundAgentInstalled,
      );

  /// True when [now] is past [lastRunAt] + the frequency's period.
  bool isDue(DateTime now) {
    final period = frequency.period;
    if (period == null) return false;
    final last = lastRunAt;
    if (last == null) return true;
    return now.difference(last) >= period;
  }

  Map<String, dynamic> toJson() => {
        'frequency': frequency.name,
        'lastRunAt': lastRunAt?.toIso8601String(),
        'runLightScrub': runLightScrub,
        'runThreatScan': runThreatScan,
        'updateDefinitions': updateDefinitions,
        'backgroundAgentInstalled': backgroundAgentInstalled,
      };

  factory ScanSchedule.fromJson(Map<String, dynamic> j) {
    final freq = ScheduleFrequency.values.firstWhere(
      (f) => f.name == j['frequency'],
      orElse: () => ScheduleFrequency.off,
    );
    final last = j['lastRunAt'] as String?;
    return ScanSchedule(
      frequency: freq,
      lastRunAt: last == null ? null : DateTime.tryParse(last),
      runLightScrub: j['runLightScrub'] as bool? ?? true,
      runThreatScan: j['runThreatScan'] as bool? ?? false,
      updateDefinitions: j['updateDefinitions'] as bool? ?? true,
      backgroundAgentInstalled:
          j['backgroundAgentInstalled'] as bool? ?? false,
    );
  }
}
