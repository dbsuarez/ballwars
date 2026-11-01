/// Deterministic admission policy for composed projectile volleys.
/// Existing shots are never evicted to make room for a new volley.
class SkillProjectileBudget {
  const SkillProjectileBudget._();

  /// Symmetric angular spread over the shots actually admitted to the arena.
  /// A capped volley with one slot must fire along the aim direction.
  static double spreadOffset({
    required int index,
    required int admitted,
    required double spreadDegrees,
  }) {
    if (admitted <= 1 || index < 0 || index >= admitted ||
        !spreadDegrees.isFinite) {
      return 0;
    }
    return (index / (admitted - 1) - 0.5) * spreadDegrees;
  }

  static int admitted({
    required int active,
    required int requested,
    required int limit,
  }) {
    if (requested <= 0 || limit <= 0 || active >= limit) return 0;
    final free = limit - (active < 0 ? 0 : active);
    return requested < free ? requested : free;
  }
}
