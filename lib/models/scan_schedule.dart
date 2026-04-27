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

/// User's schedule preferences. The runner only auto-runs in Light Scrub
/// mode — auto-running anything more aggressive without explicit user
/// confirmation is the canonical way cleaners eat data.
class ScanSchedule {
  final ScheduleFrequency frequency;
  final DateTime? lastRunAt;

  const ScanSchedule({
    required this.frequency,
    this.lastRunAt,
  });

  static const off = ScanSchedule(frequency: ScheduleFrequency.off);

  ScanSchedule copyWith({
    ScheduleFrequency? frequency,
    DateTime? lastRunAt,
  }) =>
      ScanSchedule(
        frequency: frequency ?? this.frequency,
        lastRunAt: lastRunAt ?? this.lastRunAt,
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
    );
  }
}
