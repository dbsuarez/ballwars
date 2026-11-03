import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/native_advanced_skill_config.dart';

void main() {
  final tuning = PowerUpConfig.defaults;

  test('all three native skills keep unset defaults after library serialization', () {
    final library = SkillLibrary.fromJson(SkillLibrary.defaults.toJson());
    final clone = library.activeFor(PowerUpKind.shadowClone, tuning);
    final omega = library.activeFor(PowerUpKind.omegaTendrils, tuning);
    final demon = library.activeFor(PowerUpKind.ragingDemon, tuning);
    expect(clone.projectileCount, isNull);
    expect(clone.shadowAppearSteps, isNull);
    expect(clone.shadowStrikeSteps, isNull);
    expect(clone.shadowVanishSteps, isNull);
    expect(omega.projectileCount, isNull);
    expect(omega.durationSeconds, isNull);
    expect(omega.omegaSlamOffsetRatio, isNull);
    expect(omega.omegaSlamVelocityMultiplier, isNull);
    expect(demon.projectileCount, isNull);
    expect(ShadowCloneCastSettings.resolve(
      count: clone.projectileCount, tunedCount: tuning.shadowCloneCount,
      appearanceSteps: clone.shadowAppearSteps,
      strikeIntervalSteps: clone.shadowStrikeSteps,
      disappearanceSteps: clone.shadowVanishSteps,
    ).count, tuning.shadowCloneCount);
    expect(OmegaTendrilsCastSettings.resolve(
      targetCount: omega.projectileCount, durationSeconds: omega.durationSeconds,
      slamOffsetRatio: omega.omegaSlamOffsetRatio,
      slamVelocityMultiplier: omega.omegaSlamVelocityMultiplier,
    ).holdSteps, 36);
    expect(RagingDemonCastSettings.resolve(
      configuredHits: demon.projectileCount, tunedHits: tuning.ragingDemonHits,
    ).hits, tuning.ragingDemonHits);
  });

  test('independent native overrides survive a combined library round trip', () {
    final clone = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, tuning)
        .copyWith(projectileCount: 7, shadowAppearSteps: 20,
          shadowStrikeSteps: 18, shadowVanishSteps: 10);
    final omega = SkillLibrary.defaults.builtIn(PowerUpKind.omegaTendrils, tuning)
        .copyWith(projectileCount: 2, durationSeconds: 1.5,
          omegaSlamOffsetRatio: 1.25, omegaSlamVelocityMultiplier: 2.0);
    final demon = SkillLibrary.defaults.builtIn(PowerUpKind.ragingDemon, tuning)
        .copyWith(projectileCount: 13);
    final saved = SkillLibrary.fromJson(SkillLibrary(overrides: {
      clone.id: clone, omega.id: omega, demon.id: demon,
    }).toJson());
    final c = saved.activeFor(PowerUpKind.shadowClone, tuning);
    final o = saved.activeFor(PowerUpKind.omegaTendrils, tuning);
    final d = saved.activeFor(PowerUpKind.ragingDemon, tuning);
    final cCast = ShadowCloneCastSettings.resolve(
      count: c.projectileCount, tunedCount: tuning.shadowCloneCount,
      appearanceSteps: c.shadowAppearSteps,
      strikeIntervalSteps: c.shadowStrikeSteps,
      disappearanceSteps: c.shadowVanishSteps,
    );
    final oCast = OmegaTendrilsCastSettings.resolve(
      targetCount: o.projectileCount, durationSeconds: o.durationSeconds,
      slamOffsetRatio: o.omegaSlamOffsetRatio,
      slamVelocityMultiplier: o.omegaSlamVelocityMultiplier,
    );
    final dCast = RagingDemonCastSettings.resolve(
      configuredHits: d.projectileCount, tunedHits: tuning.ragingDemonHits,
    );
    expect(cCast.count, 7);
    expect(cCast.totalDuration, 20 + 7 * 18 + 10);
    expect(oCast.targetLimit, 2);
    expect(oCast.holdSteps, 90);
    expect(oCast.slamOffsetRatio, 1.25);
    expect(oCast.slamVelocityMultiplier, 2.0);
    expect(dCast.hits, 13);
    expect(dCast.freezeSteps, 44);
  });

  test('native cast snapshots cannot change when source configuration changes', () {
    final original = OmegaTendrilsCastSettings.resolve(
      targetCount: 2, durationSeconds: 0.8,
      slamOffsetRatio: 1, slamVelocityMultiplier: 2,
    );
    final edited = OmegaTendrilsCastSettings.resolve(
      targetCount: 4, durationSeconds: 2,
      slamOffsetRatio: 2, slamVelocityMultiplier: 3,
    );
    expect(original.targetLimit, 2);
    expect(original.holdSteps, 48);
    expect(original.slamOffsetRatio, 1);
    expect(original.slamVelocityMultiplier, 2);
    expect(edited.holdSteps, 120);
    final shadow = ShadowCloneCastSettings.resolve(
      count: 3, tunedCount: 5, appearanceSteps: 15,
      strikeIntervalSteps: 10, disappearanceSteps: 11,
    );
    expect(shadow.totalDuration, 56);
    expect(ShadowCloneCastSettings.resolve(
      count: 6, tunedCount: 5, appearanceSteps: 15,
      strikeIntervalSteps: 10, disappearanceSteps: 11,
    ).totalDuration, 86);
    expect(shadow.totalDuration, 56);
  });

  test('native count reset restores admin fallback without changing other skills', () {
    final clone = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, tuning)
        .copyWith(projectileCount: 12).copyWith(projectileCount: null);
    final demon = SkillLibrary.defaults.builtIn(PowerUpKind.ragingDemon, tuning)
        .copyWith(projectileCount: 21).copyWith(projectileCount: null);
    expect(clone.projectileCount, isNull);
    expect(demon.projectileCount, isNull);
    expect(NativeAdvancedSkillConfig.cloneCount(clone.projectileCount, 9), 9);
    expect(NativeAdvancedSkillConfig.ragingDemonHits(demon.projectileCount, 17), 17);
    expect(NativeAdvancedSkillConfig.targetLimit(null), -1);
  });
}
