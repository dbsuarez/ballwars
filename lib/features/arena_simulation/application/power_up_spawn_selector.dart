import '../../../core/utils/seeded_random.dart';
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
    final available = PowerUpRarity.values.where((rarity) =>
        groups[rarity]!.isNotEmpty && tuning.rarityWeight(rarity) > 0).toList();
    final total = available.fold(0.0, (sum, rarity) => sum + tuning.rarityWeight(rarity));
    if (total <= 0) return pickups[rng.nextInt(pickups.length)];
    var draw = rng.nextDouble() * total;
    var selected = available.last;
    for (final rarity in available) {
      draw -= tuning.rarityWeight(rarity);
      if (draw < 0) { selected = rarity; break; }
    }
    final items = groups[selected]!;
    return items[rng.nextInt(items.length)];
  }
}
