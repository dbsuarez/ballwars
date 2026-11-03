import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  legacyCastingTuningMigrationRegression();
  test('casting migration preserves scale, active-follow and duration tuning', () {
    const original = SkillLibrary(custom: [
      SkillDefinition(
        id: 'custom.casting-parity',
        name: 'Casting parity',
        custom: true,
        baseKind: PowerUpKind.energyWave,
        castingSpriteId: 'cast.png',
        castingScale: 2.25,
        castingDurationSeconds: 1.75,
        castingFollowsActive: false,
      ),
    ]);
    final before = original.custom.single;
    final visualBefore = original.resolveVisual(before, SkillVisualRole.casting);
    final migrated = original.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final after = restored.custom.single;
    final visualAfter = restored.resolveVisual(after, SkillVisualRole.casting);

    expect(after.castingSpriteId, isNull);
    expect(after.castingScale, before.castingScale);
    expect(after.castingDurationSeconds, before.castingDurationSeconds);
    expect(after.castingFollowsActive, before.castingFollowsActive);
    expect(visualAfter?.spriteId, visualBefore?.spriteId);
    expect(visualAfter?.scale, visualBefore?.scale);
    expect(visualAfter?.durationSeconds, visualBefore?.durationSeconds);
    expect(restored.migrateAllLegacyArtwork().effects.length, restored.effects.length);
  });

  test('dangling explicit casting event retains playable legacy fallback', () {
    const original = SkillLibrary(custom: [
      SkillDefinition(
        id: 'custom.dangling-cast',
        name: 'Dangling cast',
        custom: true,
        baseKind: PowerUpKind.energyWave,
        castingSpriteId: 'legacy-cast.png',
        visualBindings: {
          SkillVisualRole.casting: SkillVisualBinding(effectId: 'missing-cast'),
        },
      ),
    ]);
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.custom.single.castingSpriteId, 'legacy-cast.png');
    expect(migrated.resolveVisual(migrated.custom.single, SkillVisualRole.casting)?.spriteId,
        'legacy-cast.png');
  });

  test('impact conversion preserves both Impact and Explosion visual resolution', () {
    const original = SkillLibrary(custom: [
      SkillDefinition(
        id: 'custom.impact-dual-parity',
        name: 'Impact dual parity',
        custom: true,
        baseKind: PowerUpKind.energyWave,
        impactSpriteId: 'legacy-impact.png',
      ),
    ]);
    final before = original.custom.single;
    final impactBefore = original.resolveVisual(before, SkillVisualRole.impact);
    final explosionBefore = original.resolveVisual(before, SkillVisualRole.explosion);
    final migrated = original.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final after = restored.custom.single;
    expect(after.impactSpriteId, isNull);
    expect(restored.resolveVisual(after, SkillVisualRole.impact)?.spriteId,
        impactBefore?.spriteId);
    expect(restored.resolveVisual(after, SkillVisualRole.explosion)?.spriteId,
        explosionBefore?.spriteId);
    expect(restored.resolveVisual(after, SkillVisualRole.impact)?.scale,
        impactBefore?.scale);
    expect(restored.resolveVisual(after, SkillVisualRole.explosion)?.scale,
        explosionBefore?.scale);
    expect(restored.spriteReferences(after), contains('legacy-impact.png'));
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson());
  });

  test('explicit Impact event retains its artwork while legacy Explosion fallback migrates', () {
    const original = SkillLibrary(
      effects: {
        'custom.impact-event': EffectDefinition(
          id: 'custom.impact-event',
          name: 'Authored impact',
          spriteId: 'authored-impact.png',
        ),
      },
      custom: [
        SkillDefinition(
          id: 'custom.split-impact',
          name: 'Split impact',
          custom: true,
          baseKind: PowerUpKind.energyWave,
          impactSpriteId: 'legacy-explosion.png',
          visualBindings: {
            SkillVisualRole.impact:
                SkillVisualBinding(effectId: 'custom.impact-event'),
          },
        ),
      ],
    );
    final before = original.custom.single;
    final migrated = original.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final after = restored.custom.single;
    expect(after.impactSpriteId, isNull);
    for (final role in [SkillVisualRole.impact, SkillVisualRole.explosion]) {
      expect(restored.resolveVisual(after, role)?.spriteId,
          original.resolveVisual(before, role)?.spriteId,
          reason: 'Legacy fallback changed for ${role.name}');
    }
    expect(restored.spriteReferences(after), containsAll([
      'authored-impact.png',
      'legacy-explosion.png',
    ]));
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson());
  });


  test('dangling Explosion event blocks legacy Impact removal', () {
    const original = SkillLibrary(custom: [
      SkillDefinition(
        id: 'custom.dangling-explosion',
        name: 'Dangling explosion',
        custom: true,
        baseKind: PowerUpKind.energyWave,
        impactSpriteId: 'legacy-explosion.png',
        visualBindings: {
          SkillVisualRole.explosion:
              SkillVisualBinding(effectId: 'missing-explosion'),
        },
      ),
    ]);
    final plan = original.planLegacyArtworkMigration();
    expect(plan.blockedSlots, greaterThan(0));
    final migrated = original.migrateAllLegacyArtwork();
    final after = migrated.custom.single;
    expect(after.impactSpriteId, 'legacy-explosion.png');
    for (final role in [SkillVisualRole.impact, SkillVisualRole.explosion]) {
      expect(migrated.resolveVisual(after, role)?.spriteId,
          'legacy-explosion.png');
    }
    expect(migrated.migrateAllLegacyArtwork().toJson(), migrated.toJson());
  });

  test('authored Casting event remains authoritative through migration and reload', () {
    const original = SkillLibrary(
      effects: {
        'custom.casting-event': EffectDefinition(
          id: 'custom.casting-event',
          name: 'Authored casting',
          spriteId: 'authored-cast.png',
        ),
      },
      custom: [
        SkillDefinition(
          id: 'custom.authored-cast',
          name: 'Authored cast',
          custom: true,
          baseKind: PowerUpKind.energyWave,
          castingSpriteId: 'old-cast.png',
          castingScale: 1.75,
          castingDurationSeconds: 2.5,
          castingFollowsActive: false,
          visualBindings: {
            SkillVisualRole.casting:
                SkillVisualBinding(effectId: 'custom.casting-event'),
          },
        ),
      ],
    );
    final before = original.custom.single;
    final beforeVisual = original.resolveVisual(before, SkillVisualRole.casting);
    expect(beforeVisual?.spriteId, 'authored-cast.png');
    final migrated = original.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final after = restored.custom.single;
    final afterVisual = restored.resolveVisual(after, SkillVisualRole.casting);
    expect(after.castingSpriteId, isNull);
    expect(after.castingScale, 1.75);
    expect(after.castingDurationSeconds, 2.5);
    expect(after.castingFollowsActive, false);
    expect(afterVisual?.spriteId, beforeVisual?.spriteId);
    expect(afterVisual?.scale, beforeVisual?.scale);
    expect(afterVisual?.attachment, beforeVisual?.attachment);
    expect(afterVisual?.facing, beforeVisual?.facing);
    expect(afterVisual?.playback, beforeVisual?.playback);
    expect(afterVisual?.durationSeconds, beforeVisual?.durationSeconds);
    expect(restored.activeSpriteReferences(after), contains('authored-cast.png'));
    expect(restored.activeSpriteReferences(after), isNot(contains('old-cast.png')));
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson());
  });

  test('authored Casting playback, attachment, facing and transforms survive migration', () {
    const original = SkillLibrary(
      effects: {
        'custom.cast-fx': EffectDefinition(
          id: 'custom.cast-fx',
          name: 'Custom casting FX',
          spriteId: 'custom-cast.png',
          playback: EffectPlayback.loop,
          durationSeconds: 1.25,
          scale: 1.5,
          opacity: 0.8,
        ),
      },
      custom: [
        SkillDefinition(
          id: 'custom.cast-transform',
          name: 'Cast transform',
          custom: true,
          baseKind: PowerUpKind.energyWave,
          castingSpriteId: 'old-cast.png',
          castingDurationSeconds: 2.75,
          castingFollowsActive: false,
          visualBindings: {
            SkillVisualRole.casting: SkillVisualBinding(
              effectId: 'custom.cast-fx',
              attachment: EffectAttachment.hand,
              facing: EffectFacing.direction,
              offsetX: 0.5,
              offsetY: -0.25,
              rotationDegrees: 30,
              scale: 1.2,
              opacity: 0.75,
            ),
          },
        ),
      ],
    );
    final before = original.resolveVisual(original.custom.single, SkillVisualRole.casting)!;
    final migrated = original.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final skill = restored.custom.single;
    final after = restored.resolveVisual(skill, SkillVisualRole.casting)!;
    expect(skill.castingSpriteId, isNull);
    expect(skill.castingDurationSeconds, 2.75);
    expect(skill.castingFollowsActive, false);
    expect(after.spriteId, before.spriteId);
    expect(after.scale, before.scale);
    expect(after.opacity, before.opacity);
    expect(after.tint, before.tint);
    expect(after.attachment, EffectAttachment.hand);
    expect(after.facing, EffectFacing.direction);
    expect(after.offsetX, 0.5);
    expect(after.offsetY, -0.25);
    expect(after.rotationDegrees, 30);
    expect(after.playback, EffectPlayback.loop);
    expect(after.durationSeconds, 1.25);
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson());
  });

  test('generated Casting effect ID collision does not overwrite authored event', () {
    const original = SkillLibrary(
      effects: {
        'legacy.custom.collision.casting': EffectDefinition(
          id: 'legacy.custom.collision.casting',
          name: 'Pre-existing effect',
          spriteId: 'other.png',
          playback: EffectPlayback.loop,
          durationSeconds: 1,
        ),
      },
      custom: [
        SkillDefinition(
          id: 'custom.collision',
          name: 'Collision',
          custom: true,
          baseKind: PowerUpKind.energyWave,
          castingSpriteId: 'legacy-cast.png',
        ),
      ],
    );
    final before = original.resolveVisual(original.custom.single, SkillVisualRole.casting);
    final migrated = original.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final after = restored.custom.single;
    expect(restored.effects['legacy.custom.collision.casting']?.spriteId, 'other.png');
    expect(restored.effects['legacy.custom.collision.casting']?.playback, EffectPlayback.loop);
    expect(after.visualBindings[SkillVisualRole.casting]?.effectId,
        'legacy.custom.collision.casting.1');
    expect(after.castingSpriteId, isNull);
    expect(restored.resolveVisual(after, SkillVisualRole.casting)?.spriteId,
        before?.spriteId);
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson());
  });


  test('Casting Visual Event explicit duration and legacy fallback survive reload', () {
    const library = SkillLibrary(
      effects: {
        'custom.timed-cast': EffectDefinition(
          id: 'custom.timed-cast',
          name: 'Timed cast',
          spriteId: 'timed-cast.png',
          playback: EffectPlayback.loop,
          durationSeconds: 0.75,
        ),
      },
      custom: [
        SkillDefinition(
          id: 'custom.timed-casting',
          name: 'Timed casting',
          custom: true,
          baseKind: PowerUpKind.energyWave,
          castingSpriteId: 'legacy-cast.png',
          castingDurationSeconds: 3.0,
          castingFollowsActive: true,
          visualBindings: {
            SkillVisualRole.casting: SkillVisualBinding(effectId: 'custom.timed-cast'),
          },
        ),
      ],
    );
    final migrated = library.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    final skill = restored.custom.single;
    final visual = restored.resolveVisual(skill, SkillVisualRole.casting)!;
    expect(visual.spriteId, 'timed-cast.png');
    expect(visual.durationSeconds, 0.75);
    expect(visual.playback, EffectPlayback.loop);
    expect(skill.castingDurationSeconds, 3.0);
    expect(skill.castingFollowsActive, true);
    expect(skill.castingSpriteId, isNull);
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson());
  });
}

// Regression: native casting controls are still gameplay settings after
// converting the old sprite fields to Visual Events.
void legacyCastingTuningMigrationRegression() {
  test('bulk migration preserves distinct native casting tuning for multiple skills', () {
    const library = SkillLibrary(custom: [
      SkillDefinition(
        id: 'custom.cast-a', name: 'Cast A', custom: true,
        baseKind: PowerUpKind.energyWave,
        castingSpriteId: 'cast-a.png',
        impactSpriteId: 'impact-a.png',
        castingScale: 0.75,
        castingDurationSeconds: 0.35,
        castingFollowsActive: true,
      ),
      SkillDefinition(
        id: 'custom.cast-b', name: 'Cast B', custom: true,
        baseKind: PowerUpKind.energyWave,
        castingSpriteId: 'cast-b.png',
        impactSpriteId: 'impact-b.png',
        castingScale: 2.5,
        castingDurationSeconds: 2.25,
        castingFollowsActive: false,
      ),
    ]);
    final migrated = library.migrateAllLegacyArtwork();
    final reloaded = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    for (var i = 0; i < library.custom.length; i++) {
      final before = library.custom[i];
      final after = reloaded.custom[i];
      expect(after.castingScale, before.castingScale);
      expect(after.castingDurationSeconds, before.castingDurationSeconds);
      expect(after.castingFollowsActive, before.castingFollowsActive);
      for (final role in [
        SkillVisualRole.casting,
        SkillVisualRole.impact,
        SkillVisualRole.explosion,
      ]) {
        expect(reloaded.resolveVisual(after, role)?.spriteId,
            library.resolveVisual(before, role)?.spriteId);
      }
    }
    expect(reloaded.migrateAllLegacyArtwork().toJson(), reloaded.toJson());
  });
}
