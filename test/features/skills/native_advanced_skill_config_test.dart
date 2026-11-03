import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/native_advanced_skill_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  nativeImportedValueSanitizationTests();
  test('cast snapshots preserve every native default without persisted overrides', () {
    final shadow = ShadowCloneCastSettings.resolve(
      count: null, tunedCount: 5, appearanceSteps: null,
      strikeIntervalSteps: null, disappearanceSteps: null,
    );
    expect(shadow.count, 5);
    expect(shadow.totalDuration, 12 + 5 * 14 + 12);
    final omega = OmegaTendrilsCastSettings.resolve(
      targetCount: null, durationSeconds: null,
      slamOffsetRatio: null, slamVelocityMultiplier: null,
    );
    expect(omega.targetLimit, -1);
    expect(omega.holdSteps, 36);
    expect(omega.slamOffsetRatio, 0.55);
    expect(omega.slamVelocityMultiplier, 1.0);
  });

  test('cast snapshots resolve all configured values and bound malformed imports', () {
    final shadow = ShadowCloneCastSettings.resolve(
      count: 3, tunedCount: 8, appearanceSteps: 24,
      strikeIntervalSteps: 6, disappearanceSteps: 18,
    );
    expect(shadow.totalDuration, 60);
    expect(shadow.count, 3);
    final bounded = ShadowCloneCastSettings.resolve(
      count: 999, tunedCount: 2, appearanceSteps: 0,
      strikeIntervalSteps: 9999, disappearanceSteps: -2,
    );
    expect([bounded.count, bounded.appearanceSteps,
      bounded.strikeIntervalSteps, bounded.disappearanceSteps], [100, 1, 600, 1]);
    final omega = OmegaTendrilsCastSettings.resolve(
      targetCount: 2, durationSeconds: 1.25,
      slamOffsetRatio: 1.5, slamVelocityMultiplier: 2.5,
    );
    expect([omega.targetLimit, omega.holdSteps], [2, 75]);
    expect([omega.slamOffsetRatio, omega.slamVelocityMultiplier], [1.5, 2.5]);
    final invalid = OmegaTendrilsCastSettings.resolve(
      targetCount: null, durationSeconds: double.nan,
      slamOffsetRatio: double.infinity, slamVelocityMultiplier: double.nan,
    );
    expect([invalid.holdSteps, invalid.slamOffsetRatio,
      invalid.slamVelocityMultiplier], [36, 0.55, 1.0]);
  });

  group('native cast configuration matrix', () {
    test('Raging Demon follows tuned defaults and freezes for its exact hit count', () {
      for (final tuned in <int>[1, 3, 10, 100]) {
        final settings = RagingDemonCastSettings.resolve(
          configuredHits: null, tunedHits: tuned,
        );
        expect(settings.hits, tuned);
        expect(settings.freezeSteps, tuned * 2 + 18);
      }
      final overridden = RagingDemonCastSettings.resolve(
        configuredHits: 7, tunedHits: 23,
      );
      expect(overridden.hits, 7);
      expect(overridden.freezeSteps, 32);
      expect(RagingDemonCastSettings.resolve(
        configuredHits: -4, tunedHits: 3,
      ).hits, 1);
      expect(RagingDemonCastSettings.resolve(
        configuredHits: 200, tunedHits: 3,
      ).hits, 100);
    });

    test('all three native cast settings survive saved library round-trip', () {
      final defaults = SkillLibrary.defaults;
      final shadow = defaults.builtIn(PowerUpKind.shadowClone, PowerUpConfig.defaults)
          .copyWith(projectileCount: 6, shadowAppearSteps: 19,
            shadowStrikeSteps: 11, shadowVanishSteps: 23);
      final omega = defaults.builtIn(PowerUpKind.omegaTendrils, PowerUpConfig.defaults)
          .copyWith(projectileCount: 3, durationSeconds: 1.75,
            omegaSlamOffsetRatio: 1.4, omegaSlamVelocityMultiplier: 2.2);
      final demon = defaults.builtIn(PowerUpKind.ragingDemon, PowerUpConfig.defaults)
          .copyWith(projectileCount: 9);
      final restored = SkillLibrary.fromJson(SkillLibrary(overrides: {
        shadow.id: shadow, omega.id: omega, demon.id: demon,
      }).toJson());
      final s = restored.activeFor(PowerUpKind.shadowClone, PowerUpConfig.defaults);
      final o = restored.activeFor(PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
      final d = restored.activeFor(PowerUpKind.ragingDemon, PowerUpConfig.defaults);
      final sc = ShadowCloneCastSettings.resolve(
        count: s.projectileCount, tunedCount: 2,
        appearanceSteps: s.shadowAppearSteps, strikeIntervalSteps: s.shadowStrikeSteps,
        disappearanceSteps: s.shadowVanishSteps,
      );
      final oc = OmegaTendrilsCastSettings.resolve(
        targetCount: o.projectileCount, durationSeconds: o.durationSeconds,
        slamOffsetRatio: o.omegaSlamOffsetRatio,
        slamVelocityMultiplier: o.omegaSlamVelocityMultiplier,
      );
      final dc = RagingDemonCastSettings.resolve(
        configuredHits: d.projectileCount, tunedHits: 4,
      );
      expect([sc.count, sc.appearanceSteps, sc.strikeIntervalSteps,
        sc.disappearanceSteps, sc.totalDuration], [6, 19, 11, 23, 108]);
      expect([oc.targetLimit, oc.holdSteps], [3, 105]);
      expect(oc.slamOffsetRatio, 1.4);
      expect(oc.slamVelocityMultiplier, 2.2);
      expect([dc.hits, dc.freezeSteps], [9, 36]);
    });

    test('native cast snapshots remain immutable after a later configuration change', () {
      final original = OmegaTendrilsCastSettings.resolve(
        targetCount: 2, durationSeconds: 1.0,
        slamOffsetRatio: 1.5, slamVelocityMultiplier: 3.0,
      );
      final changed = OmegaTendrilsCastSettings.resolve(
        targetCount: 5, durationSeconds: 2.0,
        slamOffsetRatio: 0.1, slamVelocityMultiplier: 0.5,
      );
      expect([original.targetLimit, original.holdSteps,
        original.slamOffsetRatio, original.slamVelocityMultiplier],
        [2, 60, 1.5, 3.0]);
      expect([changed.targetLimit, changed.holdSteps], [5, 120]);
      final shadow = ShadowCloneCastSettings.resolve(
        count: 3, tunedCount: 9, appearanceSteps: 8,
        strikeIntervalSteps: 9, disappearanceSteps: 10,
      );
      expect(shadow.totalDuration, 45);
    });
  });

  omegaSlamConfigurationRegressionTests();
  test('native reset actually clears saved overrides through copyWith and JSON', () {
    final clone = SkillLibrary.defaults
        .builtIn(PowerUpKind.shadowClone, PowerUpConfig.defaults)
        .copyWith(projectileCount: 8, shadowAppearSteps: 30);
    final omega = SkillLibrary.defaults
        .builtIn(PowerUpKind.omegaTendrils, PowerUpConfig.defaults)
        .copyWith(projectileCount: 2, durationSeconds: 1.25);
    final resetClone = clone.copyWith(projectileCount: null, shadowAppearSteps: null);
    final resetOmega = omega.copyWith(projectileCount: null, durationSeconds: null);
    expect(resetClone.projectileCount, isNull);
    expect(resetClone.shadowAppearSteps, isNull);
    expect(resetOmega.projectileCount, isNull);
    expect(resetOmega.durationSeconds, isNull);
    final saved = SkillLibrary.fromJson(SkillLibrary(overrides: {
      resetClone.id: resetClone,
      resetOmega.id: resetOmega,
    }).toJson());
    final restoredClone = saved.activeFor(PowerUpKind.shadowClone, PowerUpConfig.defaults);
    final restoredOmega = saved.activeFor(PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    expect(restoredClone.projectileCount, isNull);
    expect(restoredClone.shadowAppearSteps, isNull);
    expect(restoredOmega.projectileCount, isNull);
    expect(restoredOmega.durationSeconds, isNull);
    expect(NativeAdvancedSkillConfig.targetLimit(restoredOmega.projectileCount), -1);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(restoredOmega.durationSeconds), 36);
    // Omitting the arguments still retains overrides on ordinary edits.
    expect(omega.copyWith(name: 'Edited').durationSeconds, 1.25);
    expect(clone.copyWith(name: 'Edited').projectileCount, 8);
  });

  test('native reset handles absent editor values without resurrecting overrides', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: 9, edited: null,
      cloneFallback: 4, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.omegaTendrils, original: 3, edited: null,
      cloneFallback: 4, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(
      40, null, 12, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.5, edited: null, resetToDefaults: true,
    ), isNull);
    // Without a reset, missing editor input must retain saved values.
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(40, null, 12), 40);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.5, edited: null,
    ), 1.5);
  });

  test('Reset to Defaults clears existing native cinematic overrides', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: 7, edited: 4,
      cloneFallback: 4, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.omegaTendrils, original: 2, edited: 100,
      cloneFallback: 4, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.25, edited: 0.6, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(
      28, 12, 12, resetToDefaults: true,
    ), isNull);
  });

  test('Editing after Reset to Defaults retains explicit native overrides', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: 7, edited: 5,
      cloneFallback: 4, resetToDefaults: true,
    ), 5);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.omegaTendrils, original: 2, edited: 3,
      cloneFallback: 4, resetToDefaults: true,
    ), 3);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.25, edited: 0.9, resetToDefaults: true,
    ), 0.9);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(
      28, 20, 12, resetToDefaults: true,
    ), 20);
  });

  test('Shadow Clone timing fields round-trip and preserve missing native defaults', () {
    final baseline = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, PowerUpConfig.defaults);
    expect(baseline.shadowAppearSteps, isNull);
    expect(baseline.shadowStrikeSteps, isNull);
    expect(baseline.shadowVanishSteps, isNull);
    final custom = baseline.copyWith(shadowAppearSteps: 24, shadowStrikeSteps: 9, shadowVanishSteps: 18);
    final restored = SkillLibrary.fromJson(SkillLibrary(overrides: {custom.id: custom}).toJson())
        .activeFor(PowerUpKind.shadowClone, PowerUpConfig.defaults);
    expect([restored.shadowAppearSteps, restored.shadowStrikeSteps, restored.shadowVanishSteps], [24, 9, 18]);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(null, 12, 12), isNull);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(null, 24, 12), 24);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(24, 12, 12), 12);
  });

  test('Shadow Clone timing is bounded and isolated from other skills', () {
    final clone = SkillLibrary.defaults.builtIn(PowerUpKind.shadowClone, PowerUpConfig.defaults)
        .copyWith(shadowAppearSteps: 999, shadowStrikeSteps: 0, shadowVanishSteps: 30).validated();
    expect(clone.shadowAppearSteps, 600);
    expect(clone.shadowStrikeSteps, 1);
    expect(clone.shadowVanishSteps, 30);
    final omega = SkillLibrary.defaults.builtIn(PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    expect(omega.shadowAppearSteps, isNull);
  });

  test('native count editor keeps untouched Shadow Clone tied to admin tuning', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: null, edited: 4,
      cloneFallback: 4,
    ), isNull);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: null, edited: 6,
      cloneFallback: 4,
    ), 6);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: 6, edited: 4,
      cloneFallback: 4,
    ), 4);
  });

  test('native Omega count editor preserves unlimited target default', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.omegaTendrils, original: null, edited: 100,
      cloneFallback: 3,
    ), isNull);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.omegaTendrils, original: null, edited: 2,
      cloneFallback: 3,
    ), 2);
    expect(NativeAdvancedSkillConfig.targetLimit(null), -1);
    expect(NativeAdvancedSkillConfig.targetLimit(2), 2);
  });

  test('Raging Demon native strike count follows tuning unless explicitly overridden', () {
    expect(NativeAdvancedSkillConfig.countLabel(PowerUpKind.ragingDemon),
        'Raging Demon strikes');
    expect(NativeAdvancedSkillConfig.countHelp(PowerUpKind.ragingDemon),
        contains('administrator'));
    expect(NativeAdvancedSkillConfig.ragingDemonHits(null, 7), 7);
    expect(NativeAdvancedSkillConfig.ragingDemonHits(3, 7), 3);
    expect(NativeAdvancedSkillConfig.ragingDemonHits(200, 7), 100);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.ragingDemon, original: null, edited: 7,
      cloneFallback: 4, ragingFallback: 7,
    ), isNull);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.ragingDemon, original: null, edited: 3,
      cloneFallback: 4, ragingFallback: 7,
    ), 3);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.ragingDemon, original: 3, edited: 7,
      cloneFallback: 4, ragingFallback: 7, resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.linksCountToShells(PowerUpKind.ragingDemon), isFalse);
    final original = SkillLibrary.defaults.builtIn(
      PowerUpKind.ragingDemon, PowerUpConfig.defaults);
    expect(original.projectileCount, isNull);
    final changed = original.copyWith(projectileCount: 3);
    final restored = SkillLibrary.fromJson(SkillLibrary(
      overrides: {changed.id: changed},
    ).toJson()).activeFor(PowerUpKind.ragingDemon, PowerUpConfig.defaults);
    expect(restored.projectileCount, 3);
    expect(restored.copyWith(projectileCount: null).projectileCount, isNull);
  });

  test('native cinematic counts never synchronize with unrelated shell volleys', () {
    expect(NativeAdvancedSkillConfig.linksCountToShells(PowerUpKind.shadowClone), isFalse);
    expect(NativeAdvancedSkillConfig.linksCountToShells(PowerUpKind.omegaTendrils), isFalse);
    expect(NativeAdvancedSkillConfig.linksCountToShells(PowerUpKind.sniperRifle), isTrue);
  });

  test('native count editor labels identify cinematic behavior', () {
    expect(NativeAdvancedSkillConfig.countLabel(PowerUpKind.shadowClone),
        'Shadow clones / strikes');
    expect(NativeAdvancedSkillConfig.countLabel(PowerUpKind.omegaTendrils),
        'Maximum grabbed opponents');
    expect(NativeAdvancedSkillConfig.countHelp(PowerUpKind.shadowClone),
        contains('freeze duration'));
    expect(NativeAdvancedSkillConfig.countHelp(PowerUpKind.omegaTendrils),
        contains('all active opponents'));
    expect(NativeAdvancedSkillConfig.countLabel(PowerUpKind.sniperRifle), isNull);
  });

  test('unmodified built-in skill definitions preserve native defaults after JSON round-trip', () {
    final restored = SkillLibrary.fromJson(SkillLibrary.defaults.toJson());
    final clone = restored.activeFor(PowerUpKind.shadowClone, PowerUpConfig.defaults);
    final tendrils = restored.activeFor(PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    expect(clone.projectileCount, isNull);
    expect(tendrils.projectileCount, isNull);
    expect(NativeAdvancedSkillConfig.cloneCount(
      clone.projectileCount, PowerUpConfig.defaults.shadowCloneCount,
    ), PowerUpConfig.defaults.shadowCloneCount);
    expect(NativeAdvancedSkillConfig.targetLimit(tendrils.projectileCount), -1);
  });

  test('native cinematic overrides remain independent across JSON round-trip', () {
    final clone = SkillLibrary.defaults
        .builtIn(PowerUpKind.shadowClone, PowerUpConfig.defaults)
        .copyWith(projectileCount: 4);
    final tendrils = SkillLibrary.defaults
        .builtIn(PowerUpKind.omegaTendrils, PowerUpConfig.defaults)
        .copyWith(projectileCount: 2);
    final restored = SkillLibrary.fromJson(SkillLibrary(
      overrides: {clone.id: clone, tendrils.id: tendrils},
    ).toJson());
    expect(restored.activeFor(PowerUpKind.shadowClone, PowerUpConfig.defaults)
        .projectileCount, 4);
    expect(restored.activeFor(PowerUpKind.omegaTendrils, PowerUpConfig.defaults)
        .projectileCount, 2);
    expect(NativeAdvancedSkillConfig.cloneCount(4, 3), 4);
    expect(NativeAdvancedSkillConfig.targetLimit(2), 2);
  });

  test('native clone defaults preserve tuning', () {
    expect(NativeAdvancedSkillConfig.cloneCount(null, 4), 4);
  });
  test('native clone overrides are bounded', () {
    expect(NativeAdvancedSkillConfig.cloneCount(6, 4), 6);
    expect(NativeAdvancedSkillConfig.cloneCount(0, 4), 1);
    expect(NativeAdvancedSkillConfig.cloneCount(999, 4), 100);
  });
  test('native target cap counts eligible new grabs, not already-held targets', () {
    final owner = Object();
    final held = Object();
    final next = Object();
    final last = Object();
    final chosen = NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: [owner, held, next, last],
      isActive: (_) => true,
      isEligible: (candidate) => !identical(candidate, held),
      limit: 1,
    );
    expect(chosen, [next]);
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: [held, next, last],
      isActive: (_) => true,
      isEligible: (candidate) => !identical(candidate, held),
      limit: -1,
    ), [next, last]);
  });

  test('native selection preserves arena order and skips owner', () {
    final owner = Object();
    final a = Object();
    final b = Object();
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: [owner, a, b],
      isActive: (_) => true, limit: -1,
    ), [a, b]);
  });
  test('native selection respects target limit', () {
    final owner = Object();
    final targets = [Object(), Object(), Object()];
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: targets,
      isActive: (_) => true, limit: 2,
    ), targets.take(2).toList());
  });
  test('native selection ignores inactive and repeated players', () {
    final owner = Object();
    final inactive = Object();
    final active = Object();
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: [inactive, active, active, inactive],
      isActive: (value) => !identical(value, inactive), limit: -1,
    ), [active]);
  });
  test('native selection with zero limit is empty', () {
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: Object(), candidates: [Object()],
      isActive: (_) => true, limit: 0,
    ), isEmpty);
  });
  test('native JSON import rejects malformed overrides without losing defaults', () {
    for (final kind in [PowerUpKind.shadowClone, PowerUpKind.ragingDemon, PowerUpKind.omegaTendrils]) {
      final builtIn = SkillLibrary.defaults.builtIn(kind, PowerUpConfig.defaults);
      final json = Map<String, dynamic>.from(builtIn.toJson());
      json['projectile_count'] = double.infinity;
      json['duration_seconds'] = double.nan;
      json['shadow_appear_steps'] = 'broken';
      json['shadow_strike_steps'] = 3.5;
      json['omega_slam_offset_ratio'] = 'invalid';
      json['omega_slam_velocity_multiplier'] = double.infinity;
      final imported = SkillDefinition.fromJson(json);
      expect(imported, isNotNull);
      expect(imported!.projectileCount, isNull);
      expect(imported.durationSeconds, isNull);
      expect(imported.shadowAppearSteps, isNull);
      expect(imported.shadowStrikeSteps, isNull);
      expect(imported.omegaSlamOffsetRatio, isNull);
      expect(imported.omegaSlamVelocityMultiplier, isNull);
    }
  });

  test('native Omega hold validation discards non-finite overrides', () {
    final omega = SkillLibrary.defaults.builtIn(
      PowerUpKind.omegaTendrils, PowerUpConfig.defaults,
    );
    expect(omega.copyWith(durationSeconds: double.nan).validated().durationSeconds, isNull);
    expect(omega.copyWith(durationSeconds: double.infinity).validated().durationSeconds, isNull);
    expect(omega.copyWith(durationSeconds: 1.25).validated().durationSeconds, 1.25);
  });

  test('omega editor preserves absent duration override when unchanged', () {
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: 0.6,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: 1.25,
    ), 1.25);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.25, edited: 0.6,
    ), 0.6);
  });

  test('omega editor rejects non-finite imported values and bounds hold', () {
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: double.nan,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: double.infinity,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: -4,
    ), 0.1);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: 1000,
    ), 60.0);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.25, edited: null,
    ), 1.25);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.25, edited: null, resetToDefaults: true,
    ), isNull);
  });

  test('omega native hold duration preserves default and converts seconds to steps', () {
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(null), 36);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(0.6), 36);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(1.25), 75);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(0.01), 6);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(100), 3600);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(double.nan), 36);
  });

  test('omega hold override survives library serialization independently of target limit', () {
    final omega = SkillLibrary.defaults
        .builtIn(PowerUpKind.omegaTendrils, PowerUpConfig.defaults)
        .copyWith(durationSeconds: 1.25, projectileCount: 2);
    final restored = SkillLibrary.fromJson(SkillLibrary(
      overrides: {omega.id: omega},
    ).toJson()).activeFor(PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    expect(restored.durationSeconds, 1.25);
    expect(restored.projectileCount, 2);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(restored.durationSeconds), 75);
  });

  test('omega hold override survives skill library JSON without changing clone settings', () {
    final omega = SkillLibrary.defaults
        .builtIn(PowerUpKind.omegaTendrils, PowerUpConfig.defaults)
        .copyWith(durationSeconds: 1.25);
    final restored = SkillLibrary.fromJson(SkillLibrary(
      overrides: {omega.id: omega},
    ).toJson());
    final savedOmega = restored.activeFor(
      PowerUpKind.omegaTendrils, PowerUpConfig.defaults,
    );
    final savedClone = restored.activeFor(
      PowerUpKind.shadowClone, PowerUpConfig.defaults,
    );
    expect(savedOmega.durationSeconds, 1.25);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(savedOmega.durationSeconds), 75);
    expect(savedClone.projectileCount, isNull);
  });

  test('omega editor keeps explicit custom duration and unset default distinct', () {
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: 0.6,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 1.25, edited: 0.6,
    ), 0.6);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: null, edited: 1.25,
    ), 1.25);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(1.25), 75);
  });

  test('omega native hold rejects non-finite durations and clamps invalid bounds', () {
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(double.infinity), 36);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(double.negativeInfinity), 36);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(-5), 6);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(0), 6);
    expect(NativeAdvancedSkillConfig.omegaHoldSteps(60), 3600);
  });

  test('shadow clone native count clamps unsafe overrides but preserves default', () {
    final defaultCount = PowerUpConfig.defaults.shadowCloneCount;
    expect(NativeAdvancedSkillConfig.cloneCount(null, defaultCount), defaultCount);
    expect(NativeAdvancedSkillConfig.cloneCount(0, defaultCount), 1);
    expect(NativeAdvancedSkillConfig.cloneCount(-5, defaultCount), 1);
    expect(NativeAdvancedSkillConfig.cloneCount(101, defaultCount), 100);
  });

  test('omega defaults to every target', () {
    expect(NativeAdvancedSkillConfig.targetLimit(null), -1);
  });
  test('omega configured target count is bounded', () {
    expect(NativeAdvancedSkillConfig.targetLimit(3), 3);
    expect(NativeAdvancedSkillConfig.targetLimit(0), 1);
    expect(NativeAdvancedSkillConfig.targetLimit(999), 100);
  });

  test('native targeting distinguishes equal-valued player instances', () {
    // Regression: normal Set equality can incorrectly drop a distinct player
    // when a domain entity overrides == based on a shared display ID.
    final owner = _EqualPlayer('owner');
    final first = _EqualPlayer('shared');
    final second = _EqualPlayer('shared');
    final selected = NativeAdvancedTargetSelection.select<_EqualPlayer>(
      owner: owner,
      candidates: [first, second, first],
      isActive: (_) => true,
      limit: -1,
    );
    expect(selected, hasLength(2));
    expect(identical(selected[0], first), isTrue);
    expect(identical(selected[1], second), isTrue);
  });

  test('native targeting excludes only the actual owner instance', () {
    final owner = _EqualPlayer('shared');
    final opponent = _EqualPlayer('shared');
    final selected = NativeAdvancedTargetSelection.select<_EqualPlayer>(
      owner: owner,
      candidates: [owner, opponent],
      isActive: (_) => true,
      limit: -1,
    );
    expect(selected, hasLength(1));
    expect(identical(selected.single, opponent), isTrue);
  });

  test('native target limit counts eligible unique opponents only', () {
    final owner = Object();
    final inactive = Object();
    final first = Object();
    final second = Object();
    final third = Object();
    final selected = NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: [owner, inactive, first, first, inactive, second, third],
      isActive: (value) => !identical(value, inactive),
      limit: 2,
    );
    expect(selected, [first, second]);
  });

  test('repeated Omega casts skip held opponents before applying target cap', () {
    final owner = _EqualPlayer('owner');
    final held = _EqualPlayer('shared');
    final available = _EqualPlayer('shared');
    final later = _EqualPlayer('later');
    final heldByIdentity = <_EqualPlayer>[held];
    // The runtime uses identity membership, not value-based Set equality.
    final selected = NativeAdvancedTargetSelection.select<_EqualPlayer>(
      owner: owner,
      candidates: [owner, held, available, later],
      isActive: (_) => true,
      isEligible: (candidate) => !heldByIdentity.any(
        (target) => identical(target, candidate),
      ),
      limit: 1,
    );
    expect(selected, hasLength(1));
    expect(identical(selected.single, available), isTrue);
  });

  test('held target filtering leaves native unlimited targeting intact', () {
    final owner = Object();
    final held = Object();
    final available1 = Object();
    final available2 = Object();
    final selected = NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: [held, available1, owner, available2, held],
      isActive: (_) => true,
      isEligible: (candidate) => !identical(candidate, held),
      limit: NativeAdvancedSkillConfig.targetLimit(null),
    );
    expect(selected, [available1, available2]);
  });

  test('zero native target limit does not enumerate candidate stream', () {
    Iterable<Object> candidates() sync* {
      throw StateError('zero limit must not read candidate stream');
    }
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: Object(),
      candidates: candidates(),
      isActive: (_) => true,
      limit: 0,
    ), isEmpty);
  });

  test('unlimited native targets retain arena order after inactive duplicates', () {
    final owner = Object();
    final first = Object();
    final inactive = Object();
    final second = Object();
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: [inactive, first, owner, first, second, inactive],
      isActive: (candidate) => !identical(candidate, inactive),
      limit: NativeAdvancedSkillConfig.targetLimit(null),
    ), [first, second]);
  });

  test('native target selection stops reading candidates after reaching limit', () {
    final owner = Object();
    final first = Object();
    final second = Object();
    Iterable<Object> candidates() sync* {
      yield first;
      yield second;
      throw StateError('iterated beyond configured target limit');
    }
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner,
      candidates: candidates(),
      isActive: (_) => true,
      limit: 2,
    ), [first, second]);
  });

}


class _EqualPlayer {
  const _EqualPlayer(this.id);
  final String id;
  @override
  bool operator ==(Object other) => other is _EqualPlayer && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// Phase 2: Omega Tendrils slam configuration end-to-end persistence.
void omegaSlamConfigurationRegressionTests() {
  test('Omega slam settings round-trip and remain isolated to native Omega', () {
    final base = SkillLibrary.defaults.builtIn(
        PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    expect(base.omegaSlamOffsetRatio, isNull);
    expect(base.omegaSlamVelocityMultiplier, isNull);
    final changed = base.copyWith(
        omegaSlamOffsetRatio: 1.25, omegaSlamVelocityMultiplier: 2.5);
    final saved = SkillLibrary.fromJson(SkillLibrary(overrides: {
      changed.id: changed,
    }).toJson()).activeFor(PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    expect(saved.omegaSlamOffsetRatio, 1.25);
    expect(saved.omegaSlamVelocityMultiplier, 2.5);
    expect(NativeAdvancedSkillConfig.omegaSlamOffset(saved.omegaSlamOffsetRatio), 1.25);
    expect(NativeAdvancedSkillConfig.omegaSlamVelocity(saved.omegaSlamVelocityMultiplier), 2.5);
    final clone = SkillLibrary.defaults.builtIn(
        PowerUpKind.shadowClone, PowerUpConfig.defaults);
    expect(clone.omegaSlamOffsetRatio, isNull);
  });

  test('Omega native slam defaults, validation and reset preserve legacy runtime', () {
    expect(NativeAdvancedSkillConfig.omegaSlamOffset(null), 0.55);
    expect(NativeAdvancedSkillConfig.omegaSlamVelocity(null), 1);
    expect(NativeAdvancedSkillConfig.omegaSlamOffset(double.nan), 0.55);
    expect(NativeAdvancedSkillConfig.omegaSlamVelocity(double.infinity), 1);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: null, edited: 0.55, nativeDefault: 0.55, maximum: 3,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: 1.2, edited: 0.55, nativeDefault: 0.55, maximum: 3,
      resetToDefaults: true,
    ), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: 2.5, edited: null, nativeDefault: 1, maximum: 5,
    ), 2.5);
    final base = SkillLibrary.defaults.builtIn(
        PowerUpKind.omegaTendrils, PowerUpConfig.defaults);
    final invalid = base.copyWith(
        omegaSlamOffsetRatio: -2, omegaSlamVelocityMultiplier: 900).validated();
    expect(invalid.omegaSlamOffsetRatio, 0);
    expect(invalid.omegaSlamVelocityMultiplier, 5);
    final cleared = invalid.copyWith(
        omegaSlamOffsetRatio: null, omegaSlamVelocityMultiplier: null);
    expect(cleared.omegaSlamOffsetRatio, isNull);
    expect(cleared.omegaSlamVelocityMultiplier, isNull);
  });
}

// Phase 2: an unchanged editor must not perpetuate malformed imported values.
void nativeImportedValueSanitizationTests() {
  test('unchanged Omega imported durations normalize before save', () {
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: double.nan, edited: null), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: double.infinity, edited: null), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: -2, edited: null), 0.1);
    expect(NativeAdvancedSkillConfig.omegaEditorDuration(
      original: 120, edited: null), 60);
  });

  test('unchanged Omega imported slam settings normalize before save', () {
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: double.negativeInfinity, edited: null,
      nativeDefault: 0.55, maximum: 3), isNull);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: -2, edited: null,
      nativeDefault: 0.55, maximum: 3), 0);
    expect(NativeAdvancedSkillConfig.omegaEditorSlamValue(
      original: 8, edited: null,
      nativeDefault: 1, maximum: 5), 5);
  });

  test('unchanged imported native counts and timings are bounded', () {
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.shadowClone, original: -4, edited: null,
      cloneFallback: 3), 1);
    expect(NativeAdvancedSkillConfig.nativeEditorCount(
      kind: PowerUpKind.omegaTendrils, original: 500, edited: null,
      cloneFallback: 3), 100);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(-10, null, 12), 1);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(900, null, 12), 600);
    expect(NativeAdvancedSkillConfig.shadowEditorSteps(900, null, 12,
      resetToDefaults: true), isNull);
  });
}
