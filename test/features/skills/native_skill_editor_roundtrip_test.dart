import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/native_advanced_skill_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  final tuning = PowerUpConfig.defaults;

  test('all native count controls keep admin defaults when unchanged', () {
    for (final kind in <PowerUpKind>[
      PowerUpKind.shadowClone,
      PowerUpKind.ragingDemon,
      PowerUpKind.omegaTendrils,
    ]) {
      final defaultDisplay = kind == PowerUpKind.shadowClone
          ? tuning.shadowCloneCount.clamp(1, 100).toInt()
          : kind == PowerUpKind.ragingDemon
              ? tuning.ragingDemonHits.clamp(1, 100).toInt()
              : 100;
      final saved = NativeAdvancedSkillConfig.nativeEditorCount(
        kind: kind,
        original: null,
        edited: defaultDisplay,
        cloneFallback: tuning.shadowCloneCount,
        ragingFallback: tuning.ragingDemonHits,
      );
      expect(saved, isNull, reason: '$kind must retain native fallback');
    }
  });

  test('native editor preserves unrelated overrides and clears on reset', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone,
      original: 7, edited: null, cloneFallback: 4,
    ), 7);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone,
      original: 7, edited: null, cloneFallback: 4,
      resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(17, null, 12), 17);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(
      17, null, 12, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.5, edited: null,
    ), 1.5);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.5, edited: null, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: 2, edited: null, nativeDefault: 1, maximum: 5,
    ), 2);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: 2, edited: null, nativeDefault: 1, maximum: 5,
      resetToDefaults: true,
    ), isNull);
  });

  test('reset of one native skill does not change another saved skill', () {
    final clone = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, tuning)
        .copyWith(projectileCount: 8, shadowAppearSteps: 18);
    final omega = SkillLibrary.defaults.builtIn(PowerUpKind.omegaTendrils, tuning)
        .copyWith(projectileCount: 2, durationSeconds: 1.25,
            omegaSlamOffsetRatio: 1.5, omegaSlamVelocityMultiplier: 2.0);
    final demon = SkillLibrary.defaults.builtIn(PowerUpKind.ragingDemon, tuning)
        .copyWith(projectileCount: 11);
    final library = SkillLibrary.fromJson(SkillLibrary(overrides: {
      clone.id: clone, omega.id: omega, demon.id: demon,
    }).toJson());
    final resetClone = library.activeFor(PowerUpKind.shadowClone, tuning)
        .copyWith(projectileCount: null, shadowAppearSteps: null);
    final after = SkillLibrary.fromJson(SkillLibrary(overrides: {
      resetClone.id: resetClone,
      omega.id: library.activeFor(PowerUpKind.omegaTendrils, tuning),
      demon.id: library.activeFor(PowerUpKind.ragingDemon, tuning),
    }).toJson());
    expect(after.activeFor(PowerUpKind.shadowClone, tuning).projectileCount, isNull);
    expect(after.activeFor(PowerUpKind.shadowClone, tuning).shadowAppearSteps, isNull);
    expect(after.activeFor(PowerUpKind.omegaTendrils, tuning).durationSeconds, 1.25);
    expect(after.activeFor(PowerUpKind.omegaTendrils, tuning).projectileCount, 2);
    expect(after.activeFor(PowerUpKind.ragingDemon, tuning).projectileCount, 11);
  });

  test('native target selection excludes duplicates before enforcing limit', () {
    final owner = Object();
    final first = Object();
    final second = Object();
    final third = Object();
    final selected = NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: [owner, first, first, second, third],
      isActive: (_) => true,
      isEligible: (candidate) => !identical(candidate, first),
      limit: 2,
    );
    expect(selected, [second, third]);
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: [first, second, first, third],
      isActive: (_) => true, limit: -1,
    ), [first, second, third]);
  });

  test('native Omega duration and slam values reject non-finite edits', () {
    for (final invalid in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(NativeAdvancedSkillConfig.omegaEditorDuration(
        original: null, edited: invalid,
      ), isNull);
      expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
        original: null, edited: invalid, nativeDefault: 0.55, maximum: 3,
      ), isNull);
      expect(NativeAdvancedSkillConfig.omegaHoldSteps(invalid), 36);
      expect(NativeAdvancedSkillConfig.omegaSlamOffset(invalid), 0.55);
      expect(NativeAdvancedSkillConfig.omegaSlamVelocity(invalid), 1.0);
    }
  });
}
