import '../../../core/utils/seeded_random.dart';
import '../../skills/domain/skill_library.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';

/// Seeded rarity-weighted item selection. Traps keep their old share of eligible draws.
class PowerUpSpawnSelector {
  static PowerUpKind choose(List<PowerUpKind> eligible, PowerUpConfig tuning, SeededRandom rng) {
    assert(eligible.isNotEmpty);
    final traps = eligible.where((kind) => kind.isTrap).toList();
    final pickups = eligible.where((kind) => !kind.isTrap).toList();
    if (pickups.isEmpty) return traps[rng.nextInt(traps.length)];
    if (traps.isNotEmpty) {
      final gate = rng.nextInt(eligible.length);
      if (gate < traps.length) return traps[gate];
    }
    final groups = {
      for (final rarity in PowerUpRarity.values)
        rarity: pickups.where((kind) => tuning.rarityOf(kind) == rarity).toList(),
    };
    final selected = _pickTier(groups, tuning, rng);
    if (selected == null) return pickups[rng.nextInt(pickups.length)];
    final items = groups[selected]!;
    return items[rng.nextInt(items.length)];
  }

  /// True when some custom skill in [custom] has a tier of its own that differs from its base kind's.
  /// Only then does the spawner use [chooseSkill]; otherwise it draws exactly as before custom tiers.
  static bool customTiersDiffer(Iterable<SkillDefinition> custom, PowerUpConfig tuning) => custom.any(
    (skill) => !skill.baseKind.isTrap &&
        SkillLibrary.rarityOf(skill, tuning) != tuning.rarityOf(skill.baseKind),
  );

  /// The spawn when custom skills have tiers of their own: the same trap gate and tier-weighted pick
  /// as [choose], over entries instead of kinds. Each eligible kind is one entry in its own tier,
  /// holding its built-in (when [builtInChosen]) and the custom variants at that same tier, which
  /// share it uniformly as before. A variant at another tier is an entry of its own in that tier, so
  /// its tier sets its odds.
  static SkillDefinition chooseSkill(
    List<PowerUpKind> eligible,
    PowerUpConfig tuning,
    SeededRandom rng, {
    required SkillLibrary library,
    required List<SkillDefinition> custom,
    bool Function(PowerUpKind kind)? builtInChosen,
  }) {
    assert(eligible.isNotEmpty);
    SkillDefinition builtIn(PowerUpKind kind) => library.builtIn(kind, tuning);
    // A trap (no tier) is shared uniformly by its built-in and its custom variants, as before.
    SkillDefinition trap(PowerUpKind kind) {
      final variants = custom.where((skill) => skill.baseKind == kind).toList();
      if (variants.isEmpty) return builtIn(kind);
      final candidates = [builtIn(kind), ...variants];
      return candidates[rng.nextInt(candidates.length)];
    }

    final traps = eligible.where((kind) => kind.isTrap).toList();
    final pickups = eligible.where((kind) => !kind.isTrap).toList();
    if (pickups.isEmpty) return trap(traps[rng.nextInt(traps.length)]);
    if (traps.isNotEmpty) {
      final gate = rng.nextInt(eligible.length);
      if (gate < traps.length) return trap(traps[gate]);
    }
    final groups = {for (final rarity in PowerUpRarity.values) rarity: <List<SkillDefinition>>[]};
    for (final kind in pickups) {
      final tier = tuning.rarityOf(kind)!;
      final variants = custom.where((skill) => skill.baseKind == kind);
      final shared = [
        if (builtInChosen?.call(kind) ?? true) builtIn(kind),
        ...variants.where((skill) => SkillLibrary.rarityOf(skill, tuning) == tier),
      ];
      if (shared.isNotEmpty) groups[tier]!.add(shared);
      for (final skill in variants) {
        final own = SkillLibrary.rarityOf(skill, tuning)!;
        if (own != tier) groups[own]!.add([skill]);
      }
    }
    final entries = [for (final group in groups.values) ...group];
    if (entries.isEmpty) return builtIn(pickups[rng.nextInt(pickups.length)]);
    final selected = _pickTier(groups, tuning, rng);
    final entry = selected == null
        ? entries[rng.nextInt(entries.length)]
        : groups[selected]![rng.nextInt(groups[selected]!.length)];
    return entry.length == 1 ? entry.single : entry[rng.nextInt(entry.length)];
  }

  /// A seeded tier pick among the non-empty tiers by their weights; null when no tier has weight.
  static PowerUpRarity? _pickTier(
    Map<PowerUpRarity, List<Object>> groups,
    PowerUpConfig tuning,
    SeededRandom rng,
  ) {
    final available = PowerUpRarity.values.where((rarity) =>
        groups[rarity]!.isNotEmpty && tuning.rarityWeight(rarity) > 0).toList();
    final total = available.fold(0.0, (sum, rarity) => sum + tuning.rarityWeight(rarity));
    if (total <= 0) return null;
    var draw = rng.nextDouble() * total;
    var selected = available.last;
    for (final rarity in available) {
      draw -= tuning.rarityWeight(rarity);
      if (draw < 0) { selected = rarity; break; }
    }
    return selected;
  }
}
