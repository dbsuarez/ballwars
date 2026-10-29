import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/sprites/application/skill_sprite_readiness.dart';

const _tuning = PowerUpConfig.defaults;
const _gold = EffectDefinition(
  id: 'effect.gold',
  name: 'Gold burst',
  spriteId: 'custom.gold.burst',
  durationSeconds: 1.2,
  scale: 1.5,
  opacity: .8,
);
const _blue = EffectDefinition(
  id: 'effect.blue',
  name: 'Blue blast',
  spriteId: 'custom.blue.blast',
  playback: EffectPlayback.loop,
);

SkillLibrary _library() {
  var library = SkillLibrary.defaults.withEffect(_gold).withEffect(_blue);
  final skill = library
      .builtIn(PowerUpKind.pistol, _tuning)
      .copyWith(
        castingSpriteId: 'custom.old.cast',
        impactSpriteId: 'custom.old.hit',
        castingFollowsActive: false,
        effectDisplayScale: 2,
        visualBindings: const {
          SkillVisualRole.casting: SkillVisualBinding(effectId: 'effect.gold'),
          SkillVisualRole.impact: SkillVisualBinding(
            effectId: 'effect.gold',
            scale: .5,
            opacity: .5,
          ),
          SkillVisualRole.explosion: SkillVisualBinding(
            effectId: 'effect.blue',
          ),
        },
      );
  library = library.withDefinition(skill, _tuning);
  return library;
}

void main() {
  test(
    'Phase C placement fields and new roles survive full and compact snapshots',
    () {
      var lib = _library().withEffect(
        const EffectDefinition(
          id: 'natural',
          name: 'Natural',
          spriteId: 'qa.frames',
          playback: EffectPlayback.natural,
          durationSeconds: 4 / 60,
        ),
      );
      final skill = lib.builtIn(PowerUpKind.pistol, _tuning);
      lib = lib.withDefinition(
        skill.copyWith(
          visualBindings: {
            ...skill.visualBindings,
            SkillVisualRole.muzzle: const SkillVisualBinding(
              effectId: 'natural',
              attachment: EffectAttachment.hand,
              facing: EffectFacing.direction,
              offsetX: .25,
              offsetY: -.5,
              rotationDegrees: 30,
              tint: 0xff123456,
            ),
            SkillVisualRole.trail: const SkillVisualBinding(
              effectId: 'effect.gold',
              attachment: EffectAttachment.projectile,
              facing: EffectFacing.mirror,
              scale: 2,
              opacity: .4,
            ),
          },
        ),
        _tuning,
      );
      expect(lib.toJson()['version'], 6);
      expect(lib.toCompactJson()['version'], 7);
      for (final source in [lib.toJson(), lib.toCompactJson()]) {
        final loaded = SkillLibrary.importJson(jsonEncode(source));
        final bindings = loaded
            .builtIn(PowerUpKind.pistol, _tuning)
            .visualBindings;
        expect(
          bindings[SkillVisualRole.muzzle]!.attachment,
          EffectAttachment.hand,
        );
        expect(bindings[SkillVisualRole.muzzle]!.offsetX, .25);
        expect(bindings[SkillVisualRole.muzzle]!.offsetY, -.5);
        expect(bindings[SkillVisualRole.muzzle]!.rotationDegrees, 30);
        expect(bindings[SkillVisualRole.muzzle]!.tint, 0xff123456);
        expect(bindings[SkillVisualRole.trail]!.facing, EffectFacing.mirror);
        expect(
          loaded.effects['natural']!.durationSeconds,
          closeTo(4 / 60, 1e-9),
        );
      }
    },
  );

  test('Phase B full v4 and compact v5 effect data remains readable', () {
    for (final compact in [false, true]) {
      final data =
          jsonDecode(
                jsonEncode(
                  compact ? _library().toCompactJson() : _library().toJson(),
                ),
              )
              as Map;
      data['version'] = compact ? 5 : 4;
      for (final effect in data['effect_library']['definitions'] as List) {
        effect['version'] = 1;
      }
      for (final skill in (data['overrides'] as Map).values) {
        final bindings = skill['visual_bindings'];
        bindings['version'] = 1;
        for (final binding in (bindings['bindings'] as Map).values) {
          (binding as Map).removeWhere(
            (key, _) => !['effect', 'scale', 'opacity'].contains(key),
          );
        }
      }
      final loaded = SkillLibrary.importJson(jsonEncode(data));
      final skill = loaded.builtIn(PowerUpKind.pistol, _tuning);
      expect(skill.visualBindings, hasLength(3));
      expect(
        skill.visualBindings[SkillVisualRole.impact]!.attachment,
        EffectAttachment.automatic,
      );
      expect(
        loaded.resolveVisual(skill, SkillVisualRole.explosion)!.spriteId,
        _blue.spriteId,
      );
    }
  });

  test(
    'natural duration and unsupported attachment combinations fail clearly',
    () {
      expect(
        () => EffectDefinition.fromJson({
          ..._gold.toJson(),
          'playback': 'natural',
          'duration': null,
        }),
        throwsFormatException,
      );
      expect(
        () => parseVisualBindings({
          'version': 2,
          'bindings': {
            'trail': const SkillVisualBinding(
              effectId: 'x',
              attachment: EffectAttachment.owner,
            ).toJson(),
          },
        }),
        throwsFormatException,
      );
    },
  );
  test('legacy libraries retain old versions and exact sprite fallbacks', () {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.pistol, _tuning)
        .copyWith(
          impactSpriteId: 'old.hit',
          castingSpriteId: 'old.cast',
          castingScale: 2,
        );
    final library = SkillLibrary.defaults.withDefinition(skill, _tuning);
    expect(library.toJson()['version'], 2);
    expect(library.toCompactJson()['version'], 3);
    final loaded = SkillLibrary.importJson(jsonEncode(library.toCompactJson()));
    expect(loaded.effects, isEmpty);
    final casting = loaded.resolveVisual(
      loaded.builtIn(PowerUpKind.pistol, _tuning),
      SkillVisualRole.casting,
    )!;
    expect(casting.spriteId, 'old.cast');
    expect(casting.scale, 2);
    final hit = loaded.resolveVisual(
      loaded.builtIn(PowerUpKind.pistol, _tuning),
      SkillVisualRole.impact,
    )!;
    final blast = loaded.resolveVisual(
      loaded.builtIn(PowerUpKind.pistol, _tuning),
      SkillVisualRole.explosion,
    )!;
    expect(hit.spriteId, 'old.hit');
    expect(blast.spriteId, 'old.hit');
  });

  test(
    'full, compact and replay snapshots retain shared definitions and role bindings',
    () {
      final library = _library();
      expect(library.toJson()['version'], SkillLibrary.visualVersion);
      expect(
        library.toCompactJson()['version'],
        SkillLibrary.visualCompactVersion,
      );
      for (final loaded in [
        SkillLibrary.importJson(jsonEncode(library.toJson())),
        SkillLibrary.importJson(jsonEncode(library.toCompactJson())),
        SkillLibrary.decodeReplay(library.encodeReplay()!)!,
      ]) {
        final skill = loaded.builtIn(PowerUpKind.pistol, _tuning);
        expect(skill.visualBindings, hasLength(3));
        expect(skill.castingFollowsActive, isFalse);
        expect(loaded.effects['effect.gold']!.toJson(), _gold.toJson());
        final hit = loaded.resolveVisual(skill, SkillVisualRole.impact)!;
        expect(hit.spriteId, _gold.spriteId);
        expect(hit.scale, 1.5); // skill 2 * recipe 1.5 * binding .5
        expect(hit.opacity, .4);
        expect(hit.durationSeconds, 1.2);
        expect(
          loaded.resolveVisual(skill, SkillVisualRole.explosion)!.spriteId,
          _blue.spriteId,
        );
      }
    },
  );

  test(
    'global changes, duplicate edits and reset retain definitions without aliasing bindings',
    () {
      final library = _library().withGlobal(
        effectDisplayScale: 3,
        skillsSetEffectDisplayScale: false,
      );
      final original = library.builtIn(PowerUpKind.pistol, _tuning);
      final duplicate = library.duplicate(original, 'Other');
      final changed = duplicate.copyWith(visualBindings: {}).validated();
      final updated = library.withDefinition(changed, _tuning);
      expect(updated.effects, hasLength(2));
      expect(
        updated.builtIn(PowerUpKind.pistol, _tuning).visualBindings,
        hasLength(3),
      );
      expect(updated.byId(changed.id, _tuning)!.visualBindings, isEmpty);
      expect(
        updated.resolveVisual(original, SkillVisualRole.impact)!.scale,
        2.25,
      );
      expect(() => library.withoutEffect(_gold.id), throwsStateError);
      final unused = library.withEffect(
        const EffectDefinition(
          id: 'unused',
          name: 'Unused',
          spriteId: 'unused.sprite',
        ),
      );
      expect(unused.withoutEffect('unused').effects, hasLength(2));
    },
  );

  test(
    'readiness checks active effects while usage tracking retains legacy fallbacks',
    () {
      final library = _library();
      expect(
        SkillSpriteReadiness.dependencies(
          library: library,
          tuning: _tuning,
          kinds: {PowerUpKind.pistol},
          customIds: {},
          includeTraps: false,
        ),
        {_gold.spriteId, _blue.spriteId},
      );
    },
  );

  test(
    'invalid schemas, role names, numeric values and missing definitions fail explicitly',
    () {
      expect(
        () => EffectDefinition.fromJson({..._gold.toJson(), 'version': 99}),
        throwsFormatException,
      );
      expect(
        () => EffectDefinition.fromJson({..._gold.toJson(), 'opacity': 2}),
        throwsFormatException,
      );
      expect(
        () => parseVisualBindings({
          'version': 1,
          'bindings': {
            'unknown': {'effect': 'effect.gold'},
          },
        }),
        throwsFormatException,
      );
      final data = _library().toJson()..remove('effect_library');
      expect(
        () => SkillLibrary.importJson(jsonEncode(data)),
        throwsFormatException,
      );
    },
  );

  test(
    'missing effect definition leaves the legacy fallback unscaled by the broken binding',
    () {
      final skill = SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, _tuning)
          .copyWith(
            impactSpriteId: 'old.hit',
            visualBindings: const {
              SkillVisualRole.impact: SkillVisualBinding(
                effectId: 'missing',
                scale: 3,
                opacity: .1,
              ),
            },
          );
      final visual = SkillLibrary.defaults.resolveVisual(
        skill,
        SkillVisualRole.impact,
      )!;
      expect(visual.spriteId, 'old.hit');
      expect(visual.scale, skill.effectDisplayScale);
      expect(visual.opacity, 1);
    },
  );
}
