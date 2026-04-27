enum RiskLevel { safe, moderate, higher }

extension RiskLevelLabel on RiskLevel {
  String get label => switch (this) {
        RiskLevel.safe => 'Safe',
        RiskLevel.moderate => 'Moderate',
        RiskLevel.higher => 'Higher',
      };
}

class CacheTarget {
  final String path;
  final String name;
  final RiskLevel risk;

  const CacheTarget({
    required this.path,
    required this.name,
    required this.risk,
  });
}
