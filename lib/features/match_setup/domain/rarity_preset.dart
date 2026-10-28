import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../skills/domain/skill_library.dart';

enum RarityPreset {
  casual('Casual', 'More Epic and Special pickups'),
  balanced('Balanced', 'Recommended mix'),
  competitive('Competitive', 'More Normal pickups'),
  custom('Custom', 'Choose relative tier weights');

  const RarityPreset(this.label, this.description);
  final String label;
  final String description;

  RarityWeights resolve(RarityWeights custom) => switch (this) {
    casual => RarityWeights([35, 30, 20, 15]),
    balanced => RarityWeights([40, 30, 20, 10]),
    competitive => RarityWeights([50, 30, 15, 5]),
    RarityPreset.custom => custom,
  };
}

/// Relative tier weights, deliberately separate from the legacy tuning defaults.
class RarityWeights {
  RarityWeights(Iterable<num> values)
    : values = List.unmodifiable(values.map((value) => value.toDouble()));

  final List<double> values;
  bool get valid =>
      values.length == 4 &&
      values.every((v) => v.isFinite && v >= 0 && v <= 100) &&
      values.any((v) => v > 0);

  factory RarityWeights.fromTuning(PowerUpConfig tuning) => RarityWeights([
    for (final tier in PowerUpRarity.values) tuning.rarityWeight(tier),
  ]);

  static RarityWeights? parse(List<String> values) {
    final numbers = values.map(double.tryParse).toList();
    if (numbers.any((v) => v == null)) return null;
    final weights = RarityWeights(numbers.cast<double>());
    return weights.valid ? weights : null;
  }

  PowerUpConfig applyTo(PowerUpConfig tuning) {
    if (!valid) {
      throw ArgumentError(
        'Use four weights from 0 to 100, with at least one above zero.',
      );
    }
    for (final tier in PowerUpRarity.values) {
      tuning = tuning.withValue('rarity.${tier.name}', values[tier.index]);
    }
    return tuning;
  }
}

/// Empty-field preview of the existing selector, after traps become eligible.
/// Variants at their carrier's tier share its entry; other tiers get an entry.
class RaritySpawnOdds {
  RaritySpawnOdds._(
    this.nonTrap,
    this.allSpawns,
    this.traps,
    this.hasPickups,
    this.weighted,
  );
  final Map<PowerUpRarity, double> nonTrap;
  final Map<PowerUpRarity, double> allSpawns;
  final double traps;
  final bool hasPickups;
  final bool weighted;

  factory RaritySpawnOdds.calculate({
    required PowerUpConfig tuning,
    required SkillLibrary library,
    Set<PowerUpKind>? builtIns,
    Set<String>? customIds,
    bool includeTraps = true,
  }) {
    final custom = library.custom
        .where(
          (s) =>
              s.spawnsInArena &&
              (customIds == null || customIds.contains(s.id)),
        )
        .toList();
    final kinds = PowerUpKind.values
        .where(
          (kind) =>
              (includeTraps || !kind.isTrap) &&
              (kind.isTrap ||
                  builtIns == null ||
                  builtIns.contains(kind) ||
                  custom.any((skill) => skill.baseKind == kind)),
        )
        .toList();
    final tiers = <PowerUpRarity>{};
    for (final kind in kinds.where((kind) => !kind.isTrap)) {
      if (builtIns == null || builtIns.contains(kind)) {
        tiers.add(tuning.rarityOf(kind)!);
      }
      for (final skill in custom.where((s) => s.baseKind == kind)) {
        tiers.add(SkillLibrary.rarityOf(skill, tuning)!);
      }
    }
    final traps = kinds.isEmpty
        ? 0.0
        : kinds.where((k) => k.isTrap).length / kinds.length;
    final total = tiers.fold(
      0.0,
      (sum, tier) => sum + tuning.rarityWeight(tier),
    );
    final conditional = {
      for (final tier in PowerUpRarity.values)
        tier: total > 0 && tiers.contains(tier)
            ? tuning.rarityWeight(tier) / total
            : 0.0,
    };
    return RaritySpawnOdds._(
      conditional,
      {
        for (final tier in PowerUpRarity.values)
          tier: conditional[tier]! * (1 - traps),
      },
      traps,
      tiers.isNotEmpty,
      total > 0,
    );
  }
}
