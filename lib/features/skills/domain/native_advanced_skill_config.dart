import 'dart:collection';

import '../../arena_simulation/domain/power_up.dart';

/// Configuration adapter for native cinematic skills.
///
/// Keeps native effects and animations intact while allowing skill-library
/// projectileCount to control their hit/target count.
class NativeAdvancedSkillConfig {
  const NativeAdvancedSkillConfig._();

  /// The existing projectileCount field is also the native cinematic count
  /// for these three built-in skills. Keep this mapping explicit so editors do
  /// not misleadingly describe clone strikes or grabbed targets as bullets.
  static String? countLabel(PowerUpKind kind) => switch (kind) {
    PowerUpKind.shadowClone => 'Shadow clones / strikes',
    PowerUpKind.ragingDemon => 'Raging Demon strikes',
    PowerUpKind.omegaTendrils => 'Maximum grabbed opponents',
    _ => null,
  };

  static String? countHelp(PowerUpKind kind) => switch (kind) {
    PowerUpKind.shadowClone =>
      'Number of clones that strike in the native cinematic sequence. '
      'Changing this also changes the freeze duration. The default uses '
      'the built-in skill count.',
    PowerUpKind.ragingDemon =>
      'Number of native cinematic strikes. Without an override, follows '
      'the administrator Raging Demon hit count. Freeze time adjusts with it.',
    PowerUpKind.omegaTendrils =>
      'Maximum number of opponents grabbed by native tendrils. '
      'Without an override, all active opponents are targeted. '
      'A configured value limits the targets in arena order.',
    _ => null,
  };

  /// Shell volley count is unrelated to native cinematic hit/target count.
  /// Only projectile-based skills synchronize these two editor controls.
  static bool linksCountToShells(PowerUpKind kind) => countLabel(kind) == null;

  /// Existing tuning remains authoritative when no override is provided.
  static int cloneCount(int? configured, int fallback) =>
      (configured ?? fallback).clamp(1, 100).toInt();

  /// Raging Demon uses the existing native hit tuning unless explicitly overridden.
  static int ragingDemonHits(int? configured, int fallback) =>
      (configured ?? fallback).clamp(1, 100).toInt();

  /// An unchanged built-in count must not turn into a permanent override.
  /// In particular, a Shadow Clone default must continue following the
  /// administrator's live clone-count tuning after the skill is saved.
  /// Omega uses 100 as its editor display sentinel for "all opponents";
  /// the persisted null remains the unlimited native behavior.
  static int? nativeEditorCount({
    required PowerUpKind kind,
    required int? original,
    required int? edited,
    required int cloneFallback,
    int? ragingFallback,
    bool resetToDefaults = false,
  }) {
    if (edited == null) return resetToDefaults ? null : original?.clamp(1, 100).toInt();
    final defaultDisplay = switch (kind) {
      PowerUpKind.shadowClone => cloneFallback.clamp(1, 100).toInt(),
      PowerUpKind.ragingDemon => ragingFallback?.clamp(1, 100).toInt(),
      PowerUpKind.omegaTendrils => 100,
      _ => null,
    };
    if ((original == null || resetToDefaults) && edited == defaultDisplay) return null;
    return edited.clamp(1, 100).toInt();
  }

  /// Keep a previously unset native duration unset when the editor displays
  /// its default value. This avoids creating an override merely by opening
  /// and saving an unchanged built-in skill.
  static double? omegaEditorDuration({
    required double? original,
    required double? edited,
    bool resetToDefaults = false,
  }) {
    if (edited == null) {
      if (resetToDefaults || original == null || !original.isFinite) return null;
      return original.clamp(0.1, 60.0).toDouble();
    }
    // Malformed imported values must never be persisted as NaN or infinity.
    // The runtime already falls back to the native 36-step hold for them.
    if (!edited.isFinite) return null;
    final bounded = edited.clamp(0.1, 60.0).toDouble();
    if ((original == null || resetToDefaults) && bounded == 0.6) return null;
    return bounded;
  }

  /// Keep a native default absent when the editor has not changed it.
  static int? shadowEditorSteps(int? original, int? edited, int nativeDefault,
      {bool resetToDefaults = false}) {
    if (edited == null) return resetToDefaults ? null : original?.clamp(1, 600).toInt();
    if ((original == null || resetToDefaults) && edited == nativeDefault) return null;
    return edited.clamp(1, 600);
  }

  /// Keep native slam values unset until explicitly changed. A reset clears
  /// an existing override; unrelated edits retain it.
  static double? omegaEditorSlamValue({
    required double? original,
    required double? edited,
    required double nativeDefault,
    required double maximum,
    bool resetToDefaults = false,
  }) {
    if (edited == null) {
      if (resetToDefaults || original == null || !original.isFinite) return null;
      return original.clamp(0.0, maximum).toDouble();
    }
    if (!edited.isFinite) return null;
    final bounded = edited.clamp(0.0, maximum).toDouble();
    if ((original == null || resetToDefaults) &&
        (bounded - nativeDefault).abs() < 0.000001) {
          return null;
        }
    return bounded;
  }

  /// Native slam displacement is 0.55 target radii; native velocity is 1x.
  static double omegaSlamOffset(double? configured) =>
      configured == null || !configured.isFinite ? 0.55 : configured.clamp(0.0, 3.0).toDouble();

  static double omegaSlamVelocity(double? configured) =>
      configured == null || !configured.isFinite ? 1.0 : configured.clamp(0.0, 5.0).toDouble();

  /// Native Omega Tendrils hold lasts 36 simulation steps (0.6 seconds).
  /// A missing override must preserve the historical duration exactly.
  static int omegaHoldSteps(double? durationSeconds) {
    if (durationSeconds == null || !durationSeconds.isFinite) return 36;
    return (durationSeconds.clamp(0.1, 60.0) * 60).round();
  }

  /// -1 means every opponent (the historical Omega Tendrils behavior).
  static int targetLimit(int? configured) =>
      configured == null ? -1 : configured.clamp(1, 100).toInt();
}


/// Immutable native parameters resolved once at cast time. A skill edit during
/// an animation must never alter an in-flight cinematic attack.
class ShadowCloneCastSettings {
  const ShadowCloneCastSettings({
    required this.count,
    required this.appearanceSteps,
    required this.strikeIntervalSteps,
    required this.disappearanceSteps,
  });

  factory ShadowCloneCastSettings.resolve({
    required int? count,
    required int tunedCount,
    required int? appearanceSteps,
    required int? strikeIntervalSteps,
    required int? disappearanceSteps,
  }) => ShadowCloneCastSettings(
    count: NativeAdvancedSkillConfig.cloneCount(count, tunedCount),
    appearanceSteps: (appearanceSteps ?? 12).clamp(1, 600),
    strikeIntervalSteps: (strikeIntervalSteps ?? 14).clamp(1, 600),
    disappearanceSteps: (disappearanceSteps ?? 12).clamp(1, 600),
  );

  final int count;
  final int appearanceSteps;
  final int strikeIntervalSteps;
  final int disappearanceSteps;

  int get totalDuration => appearanceSteps + count * strikeIntervalSteps + disappearanceSteps;
}

/// Native Raging Demon strike count and freeze duration, resolved at cast time.
/// Without an override, the existing administrator tuning remains authoritative.
class RagingDemonCastSettings {
  const RagingDemonCastSettings({required this.hits});

  factory RagingDemonCastSettings.resolve({
    required int? configuredHits,
    required int tunedHits,
  }) => RagingDemonCastSettings(
    hits: NativeAdvancedSkillConfig.ragingDemonHits(configuredHits, tunedHits),
  );

  final int hits;
  int get freezeSteps => hits * 2 + 18;
}

/// Native Omega target selection and release behavior captured together.
class OmegaTendrilsCastSettings {
  const OmegaTendrilsCastSettings({
    required this.targetLimit,
    required this.holdSteps,
    required this.slamOffsetRatio,
    required this.slamVelocityMultiplier,
  });

  factory OmegaTendrilsCastSettings.resolve({
    required int? targetCount,
    required double? durationSeconds,
    required double? slamOffsetRatio,
    required double? slamVelocityMultiplier,
  }) => OmegaTendrilsCastSettings(
    targetLimit: NativeAdvancedSkillConfig.targetLimit(targetCount),
    holdSteps: NativeAdvancedSkillConfig.omegaHoldSteps(durationSeconds),
    slamOffsetRatio: NativeAdvancedSkillConfig.omegaSlamOffset(slamOffsetRatio),
    slamVelocityMultiplier: NativeAdvancedSkillConfig.omegaSlamVelocity(slamVelocityMultiplier),
  );

  final int targetLimit;
  final int holdSteps;
  final double slamOffsetRatio;
  final double slamVelocityMultiplier;
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
    bool Function(T)? isEligible,
    required int limit,
  }) {
    if (limit == 0) {
      return <T>[];
    }
    final selected = <T>[];
    // Players are runtime entities: two distinct instances can compare equal
    // by value, but must still be eligible as separate targets.
    final seen = HashSet<T>.identity();
    for (final candidate in candidates) {
      if (identical(candidate, owner) || !isActive(candidate) ||
          (isEligible != null && !isEligible(candidate)) ||
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
