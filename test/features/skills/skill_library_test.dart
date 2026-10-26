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
    expect(skills.every((skill) => skill.yell.isNotEmpty), isTrue);
    expect(
      SkillLibrary.defaults
          .builtIn(PowerUpKind.rocketLauncher, PowerUpConfig.defaults)
          .yell,
      'TARGET LOCKED!',
    );
    expect(
      SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .bubbleType,
      SkillBubbleType.shout,
    );
    expect(
      SkillLibrary.defaults
          .builtIn(PowerUpKind.apple, PowerUpConfig.defaults)
          .bubbleType,
      SkillBubbleType.speech,
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

  test('one enabled custom variant replaces its built-in skill at runtime', () {
    const tuning = PowerUpConfig.defaults;
    final source = SkillLibrary.defaults.builtIn(PowerUpKind.pistol, tuning);
    final heavy = SkillLibrary.defaults
        .duplicate(source, 'Heavy Pistol')
        .copyWith(
          enabled: true,
          arsenalDamage: 44,
          projectileSpeed: 2.5,
          spriteMode: SkillVisualMode.vector,
          effectMode: SkillVisualMode.vector,
          soundCue: 'bomb',
        );
    final library = SkillLibrary.defaults.withDefinition(heavy, tuning);

    expect(library.activeFor(PowerUpKind.pistol, tuning).name, 'Heavy Pistol');
    expect(library.applyTo(tuning).arenaDamage(PowerUpKind.pistol), 44);
    expect(
      library.applyTo(tuning).projectileSpeedRatio(PowerUpKind.pistol),
      2.5,
    );

    final faster = library
        .duplicate(source, 'Faster Pistol')
        .copyWith(enabled: true);
    final replaced = library.withDefinition(faster, tuning);
    expect(
      replaced.activeFor(PowerUpKind.pistol, tuning).name,
      'Faster Pistol',
    );
    expect(
      replaced.custom.singleWhere((item) => item.id == heavy.id).enabled,
      isFalse,
    );
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

  test('older saved built-ins recover their real arena yell', () {
    final pistol = SkillLibrary.defaults.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    );
    final json = pistol.toJson()..remove('yell');
    final library = SkillLibrary.fromJson({
      'version': 1,
      'overrides': {'builtin.pistol': json},
    });

    expect(
      library.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults).yell,
      'BANG!',
    );
  });

  test('composed chains and repeat timing round-trip and clamp', () {
    final skill = SkillLibrary.defaults
        .create('Stunning Shot', PowerUpKind.pistol)
        .copyWith(
          secondaryEffectType: SkillEffectType.freeze,
          bubbleType: SkillBubbleType.speech,
          repeatCount: 99,
          repeatIntervalSeconds: 0,
        );
    final decoded = SkillDefinition.fromJson(skill.toJson())!;

    expect(decoded.secondaryEffectType, SkillEffectType.freeze);
    expect(decoded.bubbleType, SkillBubbleType.speech);
    expect(decoded.repeatCount, 10);
    expect(decoded.repeatIntervalSeconds, 0.1);
    expect(decoded.compatibilityIssues, isEmpty);
  });

  test('impossible composed combinations explain what must change', () {
    final skill = SkillLibrary.defaults
        .create('Bad Shot', PowerUpKind.apple)
        .copyWith(
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.self,
          delivery: SkillDelivery.projectile,
        );

    expect(
      skill.compatibilityIssues,
      containsAll([
        'Projectile delivery requires the aimed fire trigger.',
        'A projectile cannot target its owner.',
      ]),
    );
  });
}
