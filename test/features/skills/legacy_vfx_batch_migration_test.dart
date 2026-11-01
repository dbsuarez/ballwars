import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const override = SkillDefinition(
    id: 'builtin.pistol', name: 'Pistol', baseKind: PowerUpKind.pistol,
    castingSpriteId: 'pistol-cast.png', impactSpriteId: 'pistol-impact.png',
  );
  const custom = SkillDefinition(
    id: 'custom.flare', name: 'Flare', baseKind: PowerUpKind.pistol,
    custom: true, castingSpriteId: 'flare-cast.png',
    impactSpriteId: 'flare-impact.png',
  );

  test('bulk conversion handles overrides and custom skills atomically', () {
    const original = SkillLibrary(
      overrides: {'builtin.pistol': override}, custom: [custom],
    );
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.effects.length, 4);
    expect(original.effects, isEmpty);
    expect(original.custom.single.castingSpriteId, 'flare-cast.png');
    final pistol = migrated.overrides['builtin.pistol']!;
    final flare = migrated.custom.single;
    for (final pair in [
      (pistol, 'pistol-cast.png', 'pistol-impact.png'),
      (flare, 'flare-cast.png', 'flare-impact.png'),
    ]) {
      expect(pair.$1.castingSpriteId, isNull);
      expect(pair.$1.impactSpriteId, isNull);
      expect(migrated.resolveVisual(pair.$1, SkillVisualRole.casting)?.spriteId,
          pair.$2);
      expect(migrated.resolveVisual(pair.$1, SkillVisualRole.impact)?.spriteId,
          pair.$3);
    }
    expect(migrated.migrateAllLegacyArtwork().effects.length, 4);
    final restored = SkillLibrary.fromJson(
        jsonDecode(jsonEncode(migrated.toJson())));
    expect(restored.effects.length, 4);
    expect(restored.custom.single.visualBindings.length, 3);
  });

  test('missing external events keep legacy artwork in bulk migration', () {
    const original = SkillLibrary(custom: [SkillDefinition(
      id: 'custom.missing', name: 'Missing', baseKind: PowerUpKind.pistol,
      custom: true, castingSpriteId: 'safe-cast.png',
      visualBindings: {
        SkillVisualRole.casting: SkillVisualBinding(effectId: 'not-imported'),
      },
    )]);
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.custom.single.castingSpriteId, 'safe-cast.png');
    expect(migrated.resolveVisual(migrated.custom.single,
        SkillVisualRole.casting)?.spriteId, 'safe-cast.png');
  });

  test('capacity failure does not mutate any input skill or effect', () {
    final effects = <String, EffectDefinition>{
      for (var i = 0; i < 255; i++)
        'existing.$i': EffectDefinition(
          id: 'existing.$i', name: 'Existing $i', spriteId: 'existing.png'),
    };
    final original = SkillLibrary(effects: effects, custom: [custom]);
    expect(() => original.migrateAllLegacyArtwork(), throwsFormatException);
    expect(original.effects.length, 255);
    expect(original.custom.single.visualBindings, isEmpty);
    expect(original.custom.single.castingSpriteId, 'flare-cast.png');
  });

  test('same sprite on distinct skills retains independent bindings', () {
    const original = SkillLibrary(custom: [
      SkillDefinition(id: 'custom.one', name: 'One',
        baseKind: PowerUpKind.pistol, custom: true,
        castingSpriteId: 'shared.png'),
      SkillDefinition(id: 'custom.two', name: 'Two',
        baseKind: PowerUpKind.pistol, custom: true,
        castingSpriteId: 'shared.png'),
    ]);
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.effects.length, 2);
    expect(migrated.custom[0].visualBindings[SkillVisualRole.casting]!.effectId,
        isNot(migrated.custom[1].visualBindings[SkillVisualRole.casting]!.effectId));
  });
}
