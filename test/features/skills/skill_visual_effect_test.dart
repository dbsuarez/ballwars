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
      expect(library.toJson()['version'], 4);
      expect(library.toCompactJson()['version'], 5);
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
