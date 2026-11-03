import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single-skill conversion preserves both visual roles and casting tuning', () {
    const skill = SkillDefinition(
      id: 'custom.single-parity', name: 'Single parity', custom: true,
      baseKind: PowerUpKind.energyWave,
      castingSpriteId: 'cast.png', impactSpriteId: 'impact.png',
      castingScale: 1.8, castingDurationSeconds: 2.4,
      castingFollowsActive: false,
    );
    const library = SkillLibrary();
    final converted = library.migrateLegacyArtwork(skill);
    final reloaded = SkillLibrary.fromJson(jsonDecode(jsonEncode(
      SkillLibrary(custom: [converted.skill], effects: converted.library.effects).toJson(),
    )));
    final after = reloaded.custom.single;
    expect(after.castingSpriteId, isNull);
    expect(after.impactSpriteId, isNull);
    expect(after.castingScale, skill.castingScale);
    expect(after.castingDurationSeconds, skill.castingDurationSeconds);
    expect(after.castingFollowsActive, skill.castingFollowsActive);
    for (final role in [
      SkillVisualRole.casting, SkillVisualRole.impact,
      SkillVisualRole.explosion,
    ]) {
      final before = library.resolveVisual(skill, role);
      final now = reloaded.resolveVisual(after, role);
      expect(now?.spriteId, before?.spriteId, reason: role.name);
      expect(now?.scale, before?.scale, reason: role.name);
      expect(now?.durationSeconds, before?.durationSeconds, reason: role.name);
      expect(now?.playback, before?.playback, reason: role.name);
    }
    final repeated = reloaded.migrateLegacyArtwork(after);
    expect(repeated.library.effects.length, reloaded.effects.length);
    expect(repeated.skill.toJson(), after.toJson());
  });

  test('single-skill migration preserves a dangling explosion fallback', () {
    const skill = SkillDefinition(
      id: 'custom.single-dangling', name: 'Single dangling', custom: true,
      baseKind: PowerUpKind.energyWave,
      impactSpriteId: 'legacy-impact.png',
      visualBindings: {
        SkillVisualRole.explosion: SkillVisualBinding(effectId: 'missing'),
      },
    );
    const library = SkillLibrary();
    final converted = library.migrateLegacyArtwork(skill);
    expect(converted.skill.impactSpriteId, 'legacy-impact.png');
    expect(converted.library.effects, isEmpty);
    expect(converted.library.resolveVisual(converted.skill, SkillVisualRole.explosion)?.spriteId,
        library.resolveVisual(skill, SkillVisualRole.explosion)?.spriteId);
  });
}
