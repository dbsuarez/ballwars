import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:characters/characters.dart';
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
    expect(
      SkillLibrary.defaults
          .builtIn(PowerUpKind.shield, PowerUpConfig.defaults)
          .trackNearestOpponent,
      isTrue,
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
    final speed = SkillLibrary.defaults
        .builtIn(PowerUpKind.speed, tuning)
        .copyWith(arsenalDamage: 8, effectStrength: 2.75);
    final maximum = SkillLibrary.defaults
        .builtIn(PowerUpKind.overcharge, tuning)
        .copyWith(durationSeconds: 4, effectStrength: 1.8);
    final repulsor = SkillLibrary.defaults
        .builtIn(PowerUpKind.repulsor, tuning)
        .copyWith(durationSeconds: 5, effectStrength: 2.1);
    final timeBubble = SkillLibrary.defaults
        .builtIn(PowerUpKind.timeBubble, tuning)
        .copyWith(durationSeconds: 6, range: 4.5);
    final freeze = SkillLibrary.defaults
        .builtIn(PowerUpKind.freeze, tuning)
        .copyWith(frozenDamageMultiplier: 2, frozenCollisionDamage: 9);
    final trackedPistol = pistol.copyWith(trackNearestOpponent: true);
    final library = SkillLibrary.defaults
        .withDefinition(trackedPistol, tuning)
        .withDefinition(shotgun, tuning)
        .withDefinition(disc, tuning)
        .withDefinition(wave, tuning)
        .withDefinition(speed, tuning)
        .withDefinition(maximum, tuning)
        .withDefinition(repulsor, tuning)
        .withDefinition(timeBubble, tuning)
        .withDefinition(freeze, tuning);
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
    expect(applied.arenaDamage(PowerUpKind.speed), 8);
    expect(applied.speedFactor, 2.75);
    expect(applied.maximumPowerSteps, 240);
    expect(applied.maximumPowerAmount, 1.8);
    expect(applied.repulsorSteps, 300);
    expect(applied.repulsorForce, 2.1);
    expect(applied.timeBubbleSteps, 360);
    expect(applied.timeBubbleRange, 4.5);
    expect(applied.frozenDamageMultiplier, 2);
    expect(applied.frozenCollisionDamage, 9);
    expect(
      decoded.builtIn(PowerUpKind.pistol, tuning).trackNearestOpponent,
      isTrue,
    );
  });

  test('duplicates get unique stable IDs and start enabled', () {
    const tuning = PowerUpConfig.defaults;
    final source = SkillLibrary.defaults.builtIn(PowerUpKind.bow, tuning);
    final first = SkillLibrary.defaults.duplicate(source, 'Arrow Rain');
    final withFirst = SkillLibrary.defaults.withDefinition(first, tuning);
    final second = withFirst.duplicate(source, 'Arrow Rain');

    expect(first.id, 'custom.arrow-rain');
    expect(second.id, 'custom.arrow-rain-2');
    expect(first.custom, isTrue);
    expect(first.enabled, isTrue);
    expect(first.trigger, SkillTrigger.aimedFire);
    expect(first.delivery, SkillDelivery.projectile);
    expect(first.effectType, SkillEffectType.damage);
  });

  test('legacy non-composed custom weapons migrate to shared behavior', () {
    final source =
        SkillLibrary.defaults
            .builtIn(PowerUpKind.boomerang, PowerUpConfig.defaults)
            .copyWith(
              id: 'custom.boom-merang',
              name: 'Boom-merang',
              custom: true,
              arsenalDamage: 7,
              knockback: 2,
              explodesOnImpact: true,
            )
            .toJson()
          ..remove('trigger')
          ..remove('targeting')
          ..remove('delivery')
          ..remove('effect_type');
    final restored = SkillLibrary.fromJson({
      'version': 2,
      'overrides': <String, Object?>{},
      'custom': [source],
    }).custom.single;

    expect(restored.isComposed, isTrue);
    expect(restored.trigger, SkillTrigger.aimedFire);
    expect(restored.delivery, SkillDelivery.projectile);
    expect(restored.explodesOnImpact, isTrue);
    expect(restored.knockback, 2);
  });

  test('enabled custom skills sharing a template remain independent', () {
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

    expect(library.activeFor(PowerUpKind.pistol, tuning).name, 'Pistol');
    expect(
      library.applyTo(tuning).arenaDamage(PowerUpKind.pistol),
      tuning.arenaDamage(PowerUpKind.pistol),
    );
    expect(
      library.applyTo(tuning).projectileSpeedRatio(PowerUpKind.pistol),
      tuning.bulletSpeedRatio,
    );

    final faster = library
        .duplicate(source, 'Faster Pistol')
        .copyWith(enabled: true);
    final replaced = library.withDefinition(faster, tuning);
    expect(replaced.custom, hasLength(2));
    expect(
      replaced.custom.singleWhere((item) => item.id == heavy.id).enabled,
      isTrue,
    );
    expect(
      replaced.custom.singleWhere((item) => item.id == faster.id).enabled,
      isTrue,
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
    expect(skill.knockback, 99);
  });

  test(
    'built-in edits persist when tuning already includes an earlier edit',
    () {
      const defaults = PowerUpConfig.defaults;
      final first = SkillLibrary.defaults.withDefinition(
        SkillLibrary.defaults
            .builtIn(PowerUpKind.boomerang, defaults)
            .copyWith(arsenalDamage: 8, knockback: 0),
        defaults,
      );
      final applied = first.applyTo(defaults);
      final edited = first.withDefinition(
        first
            .builtIn(PowerUpKind.boomerang, applied)
            .copyWith(arsenalDamage: 7, knockback: 20),
        applied,
      );
      final reopened = SkillLibrary.fromJson(edited.toJson());
      final boomerang = reopened.builtIn(PowerUpKind.boomerang, defaults);

      expect(boomerang.arsenalDamage, 7);
      expect(boomerang.knockback, 20);
    },
  );

  test('version one definitions infer category and migrate to version two', () {
    final migrated = SkillLibrary.fromJson({
      'version': 1,
      'custom': [
        {
          'id': 'custom.snack',
          'name': 'Snack',
          'base': 'friedChicken',
          'custom': true,
        },
      ],
    });

    expect(migrated.version, SkillLibrary.currentVersion);
    expect(migrated.custom.single.resolvedCategory, SkillCategory.powerUp);
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
          arsenalDamage: 0,
          allOutDamage: 0,
          dotArsenalDamage: 6.5,
          dotAllOutDamage: 3,
          range: 0.8,
          projectileSize: 1.7,
          projectileSpin: 540,
          homing: true,
          returnsToOrigin: true,
          weaponDisplayScale: 1.4,
          weaponGripInset: 0.35,
          effectStrength: 2.2,
          healing: 23,
          shieldHits: 4,
          secondaryEffectType: SkillEffectType.freeze,
          bubbleType: SkillBubbleType.speech,
          repeatCount: 99,
          repeatIntervalSeconds: 0,
          startDelaySeconds: 99,
          tickIntervalSeconds: 0,
          cooldownSeconds: 99,
          triggerIntervalSeconds: 0,
        );
    final decoded = SkillDefinition.fromJson(skill.toJson())!;

    expect(decoded.secondaryEffectType, SkillEffectType.freeze);
    expect(decoded.arsenalDamage, 0);
    expect(decoded.allOutDamage, 0);
    expect(decoded.dotArsenalDamage, 6.5);
    expect(decoded.dotAllOutDamage, 3);
    expect(decoded.range, 0.8);
    expect(decoded.projectileSize, 1.7);
    expect(decoded.projectileSpin, 540);
    expect(decoded.homing, isTrue);
    expect(decoded.returnsToOrigin, isTrue);
    expect(decoded.weaponDisplayScale, 1.4);
    expect(decoded.weaponGripInset, 0.35);
    expect(decoded.effectStrength, 2.2);
    expect(decoded.healing, 23);
    expect(decoded.shieldHits, 4);
    expect(decoded.bubbleType, SkillBubbleType.speech);
    expect(decoded.repeatCount, 10);
    expect(decoded.repeatIntervalSeconds, 0.1);
    expect(decoded.startDelaySeconds, 30);
    expect(decoded.tickIntervalSeconds, 0.1);
    expect(decoded.cooldownSeconds, 60);
    expect(decoded.triggerIntervalSeconds, 0.5);
    expect(decoded.compatibilityIssues, isEmpty);
  });

  test('visual impact and handedness settings round-trip and clamp', () {
    final skill = SkillLibrary.defaults
        .create('Heavy Flash', PowerUpKind.pistol)
        .copyWith(
          effectColor: 0xFF22CC88,
          screenShake: 8,
          handedness: SkillHandedness.twoHanded,
        );
    final decoded = SkillDefinition.fromJson(skill.toJson())!;

    expect(decoded.effectColor, 0xFF22CC88);
    expect(decoded.screenShake, 1);
    expect(decoded.handedness, SkillHandedness.twoHanded);
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

  test('versioned JSON import round-trips and rejects unsafe shapes', () {
    const tuning = PowerUpConfig.defaults;
    final custom = SkillLibrary.defaults
        .create('Imported Pulse', PowerUpKind.apple)
        .copyWith(enabled: true);
    final source = SkillLibrary.defaults.withDefinition(custom, tuning);
    final imported = SkillLibrary.importJson(
      const JsonEncoder().convert(source.toJson()),
    );

    expect(imported.custom.single.name, 'Imported Pulse');
    expect(
      () =>
          SkillLibrary.importJson('{"version":99,"overrides":{},"custom":[]}'),
      throwsFormatException,
    );
    expect(() => SkillLibrary.importJson('[]'), throwsFormatException);
  });

  test('effect-heavy Mayhem skills show their runtime safety limits', () {
    final skill = SkillLibrary.defaults
        .create('Storm', PowerUpKind.apple)
        .copyWith(
          targeting: SkillTargeting.allOpponents,
          effectType: SkillEffectType.damageOverTime,
          repeatCount: 10,
          durationSeconds: 10,
          tickIntervalSeconds: 0.1,
        );

    expect(skill.estimatedMayhemLoad, greaterThan(120));
    expect(skill.performanceIssues, hasLength(2));
  });

  test('built-in callout styles match their actual rarity tier', () {
    const tuning = PowerUpConfig.defaults;
    for (final kind in PowerUpKind.values) {
      final skill = SkillLibrary.defaults.builtIn(kind, tuning);
      final expected = kind.isTrap
          ? SkillCalloutStyle.special
          : SkillCalloutStyle.values[tuning.rarityOf(kind)!.index];
      expect(skill.calloutStyle, expected, reason: kind.label);
    }
  });

  test('defaultGripInset matches every built-in skill', () {
    for (final kind in PowerUpKind.values) {
      expect(
        SkillLibrary.defaults
            .builtIn(kind, PowerUpConfig.defaults)
            .weaponGripInset,
        kind.defaultGripInset,
        reason: kind.name,
      );
    }
  });

  test('grip forward/back accepts -1.5..1.5 and clamps beyond', () {
    final base = SkillLibrary.defaults.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    );
    final pushed = SkillDefinition.fromJson(
      base.copyWith(weaponGripInset: -0.7).toJson(),
    )!;
    expect(pushed.weaponGripInset, -0.7);
    for (final (raw, want) in const [(-9, -1.5), (9, 1.5), (-1.5, -1.5)]) {
      final wild = SkillDefinition.fromJson(
        Map<String, Object?>.from(base.toJson())..['weapon_grip_inset'] = raw,
      )!;
      expect(wild.weaponGripInset, want);
    }
  });

  test('grip sideways and rotation round trip, clamp and default to 0', () {
    final base = SkillLibrary.defaults.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    );
    expect(base.weaponGripSide, 0);
    expect(base.weaponGripRotation, 0);
    final json = base
        .copyWith(weaponGripSide: -0.6, weaponGripRotation: 37.5)
        .toJson();
    expect(json['weapon_grip_side'], -0.6);
    expect(json['weapon_grip_rotation'], 37.5);
    final decoded = SkillDefinition.fromJson(json)!;
    expect(decoded.weaponGripSide, -0.6);
    expect(decoded.weaponGripRotation, 37.5);

    final wild = SkillDefinition.fromJson(
      Map<String, Object?>.from(base.toJson())
        ..['weapon_grip_side'] = 9
        ..['weapon_grip_rotation'] = -400,
    )!;
    expect(wild.weaponGripSide, 1.5);
    expect(wild.weaponGripRotation, -180);

    final old = Map<String, Object?>.from(base.toJson())
      ..remove('weapon_grip_side')
      ..remove('weapon_grip_rotation');
    final legacy = SkillDefinition.fromJson(old)!;
    expect(legacy.weaponGripSide, 0);
    expect(legacy.weaponGripRotation, 0);
  });

  test('default grips are left out of the JSON and replay snapshots', () {
    var library = SkillLibrary.defaults;
    library = library.withDefinition(
      library.create('Plain Pistol', PowerUpKind.pistol),
      PowerUpConfig.defaults,
    );
    for (final skill in library.all(PowerUpConfig.defaults)) {
      expect(skill.weaponGripSide, 0, reason: skill.id);
      expect(skill.weaponGripRotation, 0, reason: skill.id);
      final json = skill.toJson();
      expect(json.containsKey('weapon_grip_side'), isFalse, reason: skill.id);
      expect(
        json.containsKey('weapon_grip_rotation'),
        isFalse,
        reason: skill.id,
      );
    }
    final encoded = library.encodeReplay()!;
    final source = utf8.decode(
      base64Url.decode(encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=')),
    );
    expect(source, isNot(contains('weapon_grip_side')));
    expect(source, isNot(contains('weapon_grip_rotation')));
    final decoded = SkillLibrary.decodeReplay(encoded)!;
    expect(decoded.custom.single.weaponGripSide, 0);
    expect(decoded.custom.single.weaponGripRotation, 0);
    expect(jsonEncode(decoded.toJson()), jsonEncode(library.toJson()));
  });

  group('shell settings', () {
    final tuning = PowerUpConfig.defaults;
    SkillDefinition builtIn(PowerUpKind kind) =>
        SkillLibrary.defaults.builtIn(kind, tuning);

    test('default to today: the four guns drop brass shells', () {
      for (final kind in PowerUpKind.values) {
        final skill = builtIn(kind);
        expect(skill.shellEnabled, isNull, reason: kind.name);
        expect(skill.shellSprite, isNull, reason: kind.name);
        expect(skill.shellSize, 1, reason: kind.name);
        expect(skill.shellRandomRest, isTrue, reason: kind.name);
        expect(
          skill.dropsShells,
          SkillDefinition.defaultShellKinds.contains(kind),
          reason: kind.name,
        );
        final json = skill.toJson();
        for (final key in const [
          'shell',
          'shell_sprite',
          'shell_size',
          'shell_random_rest',
        ]) {
          expect(json.containsKey(key), isFalse, reason: '${kind.name} $key');
        }
      }
      expect(SkillDefinition.defaultShellKinds, {
        PowerUpKind.pistol,
        PowerUpKind.shotgun,
        PowerUpKind.gatling,
        PowerUpKind.freeze,
      });
      // A composed custom skill keeps today's behavior: no shells unless switched on.
      final custom = SkillLibrary.defaults.create('Pew', PowerUpKind.pistol);
      expect(custom.dropsShells, isFalse);
      expect(custom.copyWith(shellEnabled: true).dropsShells, isTrue);
    });

    test('round trip, clamp, and old JSON behaves as today', () {
      final edited = builtIn(PowerUpKind.waterGun).copyWith(
        shellEnabled: true,
        shellSprite: 'projectile.bullet',
        shellSize: 2.5,
        shellRandomRest: false,
      );
      final json = edited.toJson();
      expect(json['shell'], isTrue);
      expect(json['shell_sprite'], 'projectile.bullet');
      expect(json['shell_size'], 2.5);
      expect(json['shell_random_rest'], isFalse);
      final decoded = SkillDefinition.fromJson(jsonDecode(jsonEncode(json)))!;
      expect(decoded.shellEnabled, isTrue);
      expect(decoded.shellSprite, 'projectile.bullet');
      expect(decoded.shellSize, 2.5);
      expect(decoded.shellRandomRest, isFalse);
      expect(decoded.dropsShells, isTrue);

      final off = SkillDefinition.fromJson(
        builtIn(PowerUpKind.pistol).copyWith(shellEnabled: false).toJson(),
      )!;
      expect(off.shellEnabled, isFalse);
      expect(off.dropsShells, isFalse);
      // copyWith can clear the nullable fields again.
      final cleared = edited.copyWith(shellEnabled: null, shellSprite: null);
      expect(cleared.shellEnabled, isNull);
      expect(cleared.shellSprite, isNull);

      for (final (raw, want) in const [(0.01, 0.25), (9, 4.0), (1.5, 1.5)]) {
        final wild = SkillDefinition.fromJson(
          Map<String, Object?>.from(json)..['shell_size'] = raw,
        )!;
        expect(wild.shellSize, want);
      }
      final junk = SkillDefinition.fromJson(
        Map<String, Object?>.from(json)
          ..['shell'] = 'yes'
          ..['shell_sprite'] = '   '
          ..['shell_random_rest'] = 3,
      )!;
      expect(junk.shellEnabled, isNull);
      expect(junk.shellSprite, isNull);
      expect(junk.shellRandomRest, isTrue);

      final legacy =
          Map<String, Object?>.from(builtIn(PowerUpKind.pistol).toJson())
            ..remove('shell')
            ..remove('shell_sprite');
      final old = SkillDefinition.fromJson(legacy)!;
      expect(old.dropsShells, isTrue);
      expect(old.shellSize, 1);
      expect(old.shellRandomRest, isTrue);
    });

    test('a non-numeric shell size is ignored, not thrown on', () {
      final json = Map<String, Object?>.from(
        builtIn(PowerUpKind.pistol).copyWith(shellSize: 2).toJson(),
      )..['shell_size'] = 'big';
      final skill = SkillDefinition.fromJson(json)!;
      expect(skill.shellSize, 1);
      final library = SkillLibrary.defaults.withDefinition(
        builtIn(PowerUpKind.pistol).copyWith(shellSize: 2),
        tuning,
      );
      final exported = library.toJson();
      ((exported['overrides'] as Map)['builtin.pistol'] as Map)['shell_size'] =
          'big';
      final imported = SkillLibrary.importJson(jsonEncode(exported));
      expect(imported.builtIn(PowerUpKind.pistol, tuning).shellSize, 1);
    });

    test('shell settings survive the compact replay form', () {
      final library = SkillLibrary.defaults.withDefinition(
        builtIn(PowerUpKind.gatling).copyWith(
          shellEnabled: false,
          shellSprite: 'effect.spark',
          shellSize: 3,
          shellRandomRest: false,
        ),
        tuning,
      );
      final compact = library.toCompactJson();
      final gatling = (compact['overrides'] as Map)['builtin.gatling'] as Map;
      expect(gatling['shell'], isFalse);
      expect(gatling['shell_sprite'], 'effect.spark');
      expect(gatling['shell_size'], 3);
      expect(gatling['shell_random_rest'], isFalse);
      final back = SkillLibrary.fromJson(
        jsonDecode(jsonEncode(compact)),
      ).builtIn(PowerUpKind.gatling, tuning);
      expect(back.shellEnabled, isFalse);
      expect(back.shellSprite, 'effect.spark');
      expect(back.shellSize, 3);
      expect(back.shellRandomRest, isFalse);
      final replay = SkillLibrary.decodeReplay(library.encodeReplay()!)!;
      expect(replay.builtIn(PowerUpKind.gatling, tuning).shellSize, 3);
    });
  });

  test(
    'custom description round trips, trims, caps at 160 and defaults to empty',
    () {
      final base = SkillLibrary.defaults.create(
        'Story Knife',
        PowerUpKind.knife,
      );
      expect(base.description, '');
      expect(base.toJson().containsKey('description'), isFalse);

      final described = base
          .copyWith(description: '  Cuts\nthreads   twice.  ')
          .validated();
      expect(described.description, 'Cuts threads twice.');
      final json = described.toJson();
      expect(json['description'], 'Cuts threads twice.');
      expect(
        SkillDefinition.fromJson(json)!.description,
        'Cuts threads twice.',
      );

      final long = SkillDefinition.fromJson(
        Map<String, Object?>.from(base.toJson())..['description'] = 'x' * 300,
      )!;
      expect(long.description, 'x' * 160);

      final legacy = SkillDefinition.fromJson(
        Map<String, Object?>.from(base.toJson())..remove('description'),
      )!;
      expect(legacy.description, '');

      final wrongType = SkillDefinition.fromJson(
        Map<String, Object?>.from(base.toJson())..['description'] = 42,
      )!;
      expect(wrongType.description, '');
    },
  );

  test(
    'built-in descriptions are kept in their override and travel in snapshots',
    () {
      const tuning = PowerUpConfig.defaults;
      final knife = SkillLibrary.defaults
          .builtIn(PowerUpKind.knife, tuning)
          .copyWith(description: '  A short\nblade.  ');
      expect(knife.validated().description, 'A short blade.');
      expect(
        SkillDefinition.fromJson(knife.validated().toJson())!.description,
        'A short blade.',
      );
      expect(
        knife.copyWith(description: 'x' * 300).validated().description,
        'x' * 160,
      );

      // The description alone makes an override; clearing it removes the override again.
      final library = SkillLibrary.defaults.withDefinition(knife, tuning);
      expect(library.overrides.keys, ['builtin.knife']);
      expect(
        library.builtIn(PowerUpKind.knife, tuning).description,
        'A short blade.',
      );
      final cleared = library.withDefinition(
        library.builtIn(PowerUpKind.knife, tuning).copyWith(description: ''),
        tuning,
      );
      expect(cleared.overrides, isEmpty);
      expect(cleared.isDefault, isTrue);

      // Saved JSON, the full snapshot and the compact snapshot all keep it.
      final compact = library.toCompactJson();
      expect(
        ((compact['overrides'] as Map)['builtin.knife'] as Map)['description'],
        'A short blade.',
      );
      for (final read in [
        SkillLibrary.fromJson(jsonDecode(jsonEncode(library.toJson()))),
        SkillLibrary.fromJson(compact),
        SkillLibrary.importJson(jsonEncode(compact)),
        SkillLibrary.decodeReplay(library.encodeReplay()!)!,
      ]) {
        expect(
          read.builtIn(PowerUpKind.knife, tuning).description,
          'A short blade.',
        );
      }
    },
  );

  test('descriptions are cut on characters, never inside an emoji', () {
    // Each family emoji is one character but many UTF-16 units.
    const family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';
    final emojis = SkillDefinition.cleanDescription(family * 200);
    expect(emojis, family * SkillDefinition.maxDescriptionLength);
    expect(emojis.characters.length, SkillDefinition.maxDescriptionLength);
    // A flag (two regional indicators) right at the cut stays whole.
    final flag = '\u{1F1F5}\u{1F1ED}';
    final mixed = SkillDefinition.cleanDescription('a' * 159 + flag * 3);
    expect(mixed, 'a' * 159 + flag);
    // No lone surrogate survives the cut.
    final lone = RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])');
    expect(lone.hasMatch(mixed), isFalse);
    expect(() => jsonEncode(mixed), returnsNormally);

    final noSpaces = SkillDefinition.cleanDescription('word' * 100);
    expect(noSpaces, ('word' * 100).substring(0, 160));
  });

  test('replay snapshots carry descriptions and still enforce their limit', () {
    final description = 'd' * 160;
    var library = SkillLibrary.defaults;
    for (var i = 0; i < 20; i++) {
      library = library.withDefinition(
        library
            .create('Story Skill $i', PowerUpKind.pistol)
            .copyWith(description: description),
        PowerUpConfig.defaults,
      );
    }
    final encoded = library.encodeReplay()!;
    final decoded = SkillLibrary.decodeReplay(encoded)!;
    expect(decoded.custom, hasLength(20));
    expect(decoded.custom.every((s) => s.description == description), isTrue);

    var full = library;
    for (
      var i = 20;
      jsonEncode(full.toCompactJson()).length <=
          SkillLibrary.maxReplayCharacters;
      i++
    ) {
      full = full.withDefinition(
        full
            .create('Story Skill $i', PowerUpKind.pistol)
            .copyWith(description: description),
        PowerUpConfig.defaults,
      );
    }
    expect(full.encodeReplay, throwsFormatException);
  });

  test('melee reach round trips, clamps to 0..3 and defaults to 0', () {
    for (final skill in SkillLibrary.defaults.all(PowerUpConfig.defaults)) {
      expect(skill.meleeReach, 0, reason: skill.id);
    }
    final base = SkillLibrary.defaults.builtIn(
      PowerUpKind.knife,
      PowerUpConfig.defaults,
    );
    // Left out at 0, so existing snapshots keep their size.
    expect(base.toJson().containsKey('melee_reach'), isFalse);
    final json = base.copyWith(meleeReach: 1.25).toJson();
    expect(json['melee_reach'], 1.25);
    expect(SkillDefinition.fromJson(json)!.meleeReach, 1.25);
    final wild = SkillDefinition.fromJson(
      Map<String, Object?>.from(base.toJson())..['melee_reach'] = 9,
    )!;
    expect(wild.meleeReach, 3);
    final negative = SkillDefinition.fromJson(
      Map<String, Object?>.from(base.toJson())..['melee_reach'] = -2,
    )!;
    expect(negative.meleeReach, 0);
  });

  test('hilted weapons default to an inset hand grip', () {
    for (final kind in const [
      PowerUpKind.knife,
      PowerUpKind.sword,
      PowerUpKind.busterSword,
    ]) {
      expect(
        SkillLibrary.defaults
            .builtIn(kind, PowerUpConfig.defaults)
            .weaponGripInset,
        0.2,
        reason: kind.label,
      );
    }
  });

  test('advanced targeting and delivery choices round-trip', () {
    final skill = SkillLibrary.defaults
        .create('Directional Beam', PowerUpKind.energyWave)
        .copyWith(
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.beam,
        );
    final decoded = SkillDefinition.fromJson(skill.toJson())!;
    expect(decoded.targeting, SkillTargeting.chosenDirection);
    expect(decoded.delivery, SkillDelivery.beam);

    final boundary = skill.copyWith(
      targeting: SkillTargeting.arenaLocation,
      delivery: SkillDelivery.boundaryHazard,
    );
    final decodedBoundary = SkillDefinition.fromJson(boundary.toJson())!;
    expect(decodedBoundary.targeting, SkillTargeting.arenaLocation);
    expect(decodedBoundary.delivery, SkillDelivery.boundaryHazard);
  });
}
