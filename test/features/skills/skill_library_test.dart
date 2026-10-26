import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every arena item has a stable built-in skill definition', () {
    final skills = SkillLibrary.defaults.all(PowerUpConfig.defaults);
    expect(skills, hasLength(PowerUpKind.values.length));
    expect(skills.map((skill) => skill.id).toSet(), hasLength(skills.length));
    expect(
      skills.map((skill) => skill.baseKind).toSet(),
      containsAll(PowerUpKind.values),
    );
  });

  test('built-in edits apply to live tuning and round-trip as JSON', () {
    const tuning = PowerUpConfig.defaults;
    final pistol = SkillLibrary.defaults
        .builtIn(PowerUpKind.pistol, tuning)
        .copyWith(arsenalDamage: 27, allOutDamage: 11);
    final shotgun = SkillLibrary.defaults
        .builtIn(PowerUpKind.shotgun, tuning)
        .copyWith(projectileCount: 9, projectileSpeed: 2.4, spreadDegrees: 70);
    final disc = SkillLibrary.defaults
        .builtIn(PowerUpKind.ricochetDisc, tuning)
        .copyWith(maxBounces: 4);
    final wave = SkillLibrary.defaults
        .builtIn(PowerUpKind.energyWave, tuning)
        .copyWith(knockback: 2.5);
    final library = SkillLibrary.defaults
        .withDefinition(pistol, tuning)
        .withDefinition(shotgun, tuning)
        .withDefinition(disc, tuning)
        .withDefinition(wave, tuning);
    final decoded = SkillLibrary.fromJson(library.toJson());
    final applied = decoded.applyTo(tuning);

    expect(applied.arenaDamage(PowerUpKind.pistol), 27);
    expect(applied.allOutThreads(PowerUpKind.pistol), 11);
    expect(applied.shotgunPellets, 9);
    expect(applied.projectileSpeedRatio(PowerUpKind.shotgun), 2.4);
    expect(
      applied.shotgunSpreadRadians,
      closeTo(70 * 3.141592653589793 / 180, 0.0001),
    );
    expect(applied.maxBounces(PowerUpKind.ricochetDisc), 4);
    expect(applied.knockback(PowerUpKind.energyWave), 2.5);
  });

  test('duplicates get unique stable IDs and start disabled', () {
    const tuning = PowerUpConfig.defaults;
    final source = SkillLibrary.defaults.builtIn(PowerUpKind.bow, tuning);
    final first = SkillLibrary.defaults.duplicate(source, 'Arrow Rain');
    final withFirst = SkillLibrary.defaults.withDefinition(first, tuning);
    final second = withFirst.duplicate(source, 'Arrow Rain');

    expect(first.id, 'custom.arrow-rain');
    expect(second.id, 'custom.arrow-rain-2');
    expect(first.custom, isTrue);
    expect(first.enabled, isFalse);
  });

  test('untrusted definitions are clamped on load', () {
    final library = SkillLibrary.fromJson({
      'version': 1,
      'custom': [
        {
          'id': 'custom.wild',
          'name': 'Wild',
          'base': 'pistol',
          'custom': true,
          'arsenal_damage': 9999,
          'projectile_count': 999,
          'knockback': 99,
        },
      ],
    });
    final skill = library.custom.single;
    expect(skill.arsenalDamage, 500);
    expect(skill.projectileCount, 100);
    expect(skill.knockback, 10);
  });
}
