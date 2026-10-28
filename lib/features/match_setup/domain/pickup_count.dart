import '../../arena_simulation/domain/power_up.dart';

/// (on, total) pickups: the built-in non-trap kinds in [builtIn] plus [customOn] of [customTotal]
/// custom skills. Traps always spawn, so they are never counted. Match Setup's Pickups row, its
/// footer and the Weapons dialog all count through this, so they always agree.
(int, int) pickupCount(
  Iterable<PowerUpKind> builtIn,
  int customOn,
  int customTotal,
) {
  final kinds = PowerUpKind.values.where((kind) => !kind.isTrap);
  final set = builtIn.toSet();
  return (
    kinds.where(set.contains).length + customOn,
    kinds.length + customTotal,
  );
}
