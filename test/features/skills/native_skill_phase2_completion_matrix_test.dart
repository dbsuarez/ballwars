import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/native_advanced_skill_config.dart';

void main() {
  final tuning = PowerUpConfig.defaults;

  test('native defaults remain unset after repeated library round trips', () {
    var library = SkillLibrary.defaults;
    for (var i = 0; i < 3; i++) {
      library = SkillLibrary.fromJson(library.toJson());
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
      expect(NativeAdvancedSkillConfig.targetLimit(omega.projectileCount), -1);
      expect(NativeAdvancedSkillConfig.omegaHoldSteps(omega.durationSeconds), 36);
    }
  });

  test('native cast parameters remain isolated across serialized skill overrides', () {
    final clone = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, tuning)
        .copyWith(projectileCount: 4, shadowAppearSteps: 19,
          shadowStrikeSteps: 16, shadowVanishSteps: 13);
    final omega = SkillLibrary.defaults.builtIn(PowerUpKind.omegaTendrils, tuning)
        .copyWith(projectileCount: 3, durationSeconds: 1.2,
          omegaSlamOffsetRatio: 1.3, omegaSlamVelocityMultiplier: 2.4);
    final demon = SkillLibrary.defaults.builtIn(PowerUpKind.ragingDemon, tuning)
        .copyWith(projectileCount: 17);
    final restored = SkillLibrary.fromJson(SkillLibrary(overrides: {
      clone.id: clone, omega.id: omega, demon.id: demon,
    }).toJson());
    final c = restored.activeFor(PowerUpKind.shadowClone, tuning);
    final o = restored.activeFor(PowerUpKind.omegaTendrils, tuning);
    final d = restored.activeFor(PowerUpKind.ragingDemon, tuning);
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
    expect(cCast.totalDuration, 19 + 4 * 16 + 13);
    expect(oCast.targetLimit, 3);
    expect(oCast.holdSteps, 72);
    expect(oCast.slamOffsetRatio, 1.3);
    expect(oCast.slamVelocityMultiplier, 2.4);
    expect(dCast.hits, 17);
    expect(dCast.freezeSteps, 52);
  });

  test('native reset clears only native overrides and restores tuned fallbacks', () {
    final clone = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, tuning)
        .copyWith(projectileCount: 9, shadowAppearSteps: 21,
          shadowStrikeSteps: 25, shadowVanishSteps: 17)
        .copyWith(projectileCount: null, shadowAppearSteps: null,
          shadowStrikeSteps: null, shadowVanishSteps: null);
    final omega = SkillLibrary.defaults.builtIn(PowerUpKind.omegaTendrils, tuning)
        .copyWith(projectileCount: 2, durationSeconds: 2.0,
          omegaSlamOffsetRatio: 1.4, omegaSlamVelocityMultiplier: 2.5)
        .copyWith(projectileCount: null, durationSeconds: null,
          omegaSlamOffsetRatio: null, omegaSlamVelocityMultiplier: null);
    final demon = SkillLibrary.defaults.builtIn(PowerUpKind.ragingDemon, tuning)
        .copyWith(projectileCount: 20).copyWith(projectileCount: null);
    final restored = SkillLibrary.fromJson(SkillLibrary(overrides: {
      clone.id: clone, omega.id: omega, demon.id: demon,
    }).toJson());
    final c = restored.activeFor(PowerUpKind.shadowClone, tuning);
    final o = restored.activeFor(PowerUpKind.omegaTendrils, tuning);
    final d = restored.activeFor(PowerUpKind.ragingDemon, tuning);
    expect(ShadowCloneCastSettings.resolve(
      count: c.projectileCount, tunedCount: tuning.shadowCloneCount,
      appearanceSteps: c.shadowAppearSteps,
      strikeIntervalSteps: c.shadowStrikeSteps,
      disappearanceSteps: c.shadowVanishSteps,
    ).count, tuning.shadowCloneCount);
    expect(OmegaTendrilsCastSettings.resolve(
      targetCount: o.projectileCount, durationSeconds: o.durationSeconds,
      slamOffsetRatio: o.omegaSlamOffsetRatio,
      slamVelocityMultiplier: o.omegaSlamVelocityMultiplier,
    ).holdSteps, 36);
    expect(NativeAdvancedSkillConfig.targetLimit(o.projectileCount), -1);
    expect(RagingDemonCastSettings.resolve(
      configuredHits: d.projectileCount, tunedHits: tuning.ragingDemonHits,
    ).hits, tuning.ragingDemonHits);
  });
}
