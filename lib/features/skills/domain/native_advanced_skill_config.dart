/// Configuration adapter for native cinematic skills.
///
/// Keeps native effects and animations intact while allowing skill-library
/// projectileCount to control their hit/target count.
class NativeAdvancedSkillConfig {
  const NativeAdvancedSkillConfig._();

  /// Existing tuning remains authoritative when no override is provided.
  static int cloneCount(int? configured, int fallback) =>
      (configured ?? fallback).clamp(1, 100).toInt();

  /// -1 means every opponent (the historical Omega Tendrils behavior).
  static int targetLimit(int? configured) =>
      configured == null ? -1 : configured.clamp(1, 100).toInt();
}


/// Stable, bounded selection for native multi-target cinematic attacks.
/// Preserves arena order for backward compatibility and never selects
/// the owner, inactive players, or the same player twice.
class NativeAdvancedTargetSelection {
  const NativeAdvancedTargetSelection._();

  static List<T> select<T>({
    required T owner,
    required Iterable<T> candidates,
    required bool Function(T) isActive,
    required int limit,
  }) {
    if (limit == 0) {
      return <T>[];
    }
    final selected = <T>[];
    final seen = <T>{};
    for (final candidate in candidates) {
      if (identical(candidate, owner) || !isActive(candidate) ||
          !seen.add(candidate)) {
        continue;
      }
      selected.add(candidate);
      if (limit > 0 && selected.length >= limit) {
        break;
      }
    }
    return selected;
  }
}
