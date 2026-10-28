import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  const tuning = PowerUpConfig.defaults;

  SkillLibrary withCustom() {
    var library = SkillLibrary.defaults;
    for (final name in ['One', 'Two']) {
      library = library.withDefinition(
        library
            .create(name, PowerUpKind.pistol)
            .copyWith(bubbleDurationSeconds: 2, projectileCount: 4),
        tuning,
      );
    }
    return library;
  }

  test('applyToAll sets the callout on every skill and leaves the rest', () {
    final before = withCustom();
    final after = before.applyToAll(tuning, calloutSeconds: 3);
    final skills = after.all(tuning);
    expect(skills, hasLength(PowerUpKind.values.length + 2));
    for (final skill in skills) {
      expect(skill.bubbleDurationSeconds, 3, reason: skill.id);
    }
    for (final kind in PowerUpKind.values) {
      final was = before.builtIn(kind, tuning);
      final now = after.builtIn(kind, tuning);
      expect(
        now.copyWith(bubbleDurationSeconds: was.bubbleDurationSeconds).toJson(),
        was.toJson(),
        reason: kind.name,
      );
    }
    for (final skill in after.custom) {
      expect(skill.projectileCount, 4);
    }
    // The global settings are untouched.
    expect(after.skillsSetCallout, isTrue);
    expect(after.calloutSeconds, SkillLibrary.defaultCalloutSeconds);
  });

  test('applyToAll keeps the other edits of existing overrides', () {
    final edited = SkillLibrary.defaults.withDefinition(
      SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, tuning)
          .copyWith(yell: 'PEW!', weaponDisplayScale: 2),
      tuning,
    );
    final after = edited.applyToAll(tuning, screenShake: 0.7);
    final pistol = after.builtIn(PowerUpKind.pistol, tuning);
    expect(pistol.yell, 'PEW!');
    expect(pistol.weaponDisplayScale, 2);
    expect(pistol.screenShake, 0.7);
  });

  test('applyToAll sets each scale, clamps, and without values is a no-op', () {
    final library = withCustom();
    expect(identical(library.applyToAll(tuning), library), isTrue);
    final after = library.applyToAll(
      tuning,
      weaponDisplayScale: 2,
      pickupDisplayScale: 9,
      effectDisplayScale: 0.5,
      screenShake: -1,
      calloutSeconds: 99,
    );
    for (final skill in after.all(tuning)) {
      expect(skill.weaponDisplayScale, 2);
      expect(skill.pickupDisplayScale, 3);
      expect(skill.effectDisplayScale, 0.5);
      expect(skill.screenShake, 0);
      expect(skill.bubbleDurationSeconds, 10);
    }
  });

  test('global sprite sizes: each skill sets its own until switched off', () {
    final skill = SkillLibrary.defaults
        .create('Big', PowerUpKind.pistol)
        .copyWith(
          weaponDisplayScale: 2,
          pickupDisplayScale: 1.5,
          effectDisplayScale: 0.5,
        );
    const library = SkillLibrary.defaults;
    expect(library.weaponDisplayScaleFor(skill), 2);
    expect(library.pickupDisplayScaleFor(skill), 1.5);
    expect(library.effectDisplayScaleFor(skill), 0.5);
    final global = library.withGlobal(
      weaponDisplayScale: 1.25,
      skillsSetWeaponDisplayScale: false,
      pickupDisplayScale: 0.75,
      skillsSetPickupDisplayScale: false,
      effectDisplayScale: 9,
      skillsSetEffectDisplayScale: false,
    );
    expect(global.weaponDisplayScaleFor(skill), 1.25);
    expect(global.pickupDisplayScaleFor(skill), 0.75);
    expect(global.effectDisplayScaleFor(skill), 3);
    expect(global.isDefault, isFalse);
    final edited = global.withDefinition(skill, tuning);
    for (final l in [
      edited,
      edited.removeCustom(skill.id),
      SkillLibrary.fromJson(jsonDecode(jsonEncode(edited.toJson()))),
      SkillLibrary.decodeReplay(edited.encodeReplay()!)!,
    ]) {
      expect(l.weaponDisplayScale, 1.25);
      expect(l.skillsSetWeaponDisplayScale, isFalse);
      expect(l.pickupDisplayScale, 0.75);
      expect(l.skillsSetPickupDisplayScale, isFalse);
      expect(l.effectDisplayScale, 3);
      expect(l.skillsSetEffectDisplayScale, isFalse);
    }
    // Libraries saved before have none of them, and their JSON is unchanged.
    expect(SkillLibrary.defaults.toJson().keys, [
      'version',
      'overrides',
      'custom',
    ]);
  });

  test('replay snapshot of a fully edited library stays well under the cap', () {
    var library = SkillLibrary.defaults;
    final text = 'x' * 160;
    for (var i = 0; i < 10; i++) {
      library = library.withDefinition(
        library
            .create('Custom $i', PowerUpKind.values[i])
            .copyWith(description: text),
        tuning,
      );
    }
    library = library.applyToAll(
      tuning,
      calloutSeconds: 2,
      screenShake: 0.5,
      weaponDisplayScale: 1.5,
      pickupDisplayScale: 1.5,
      effectDisplayScale: 1.5,
    );
    expect(library.overrides, hasLength(PowerUpKind.values.length));
    // The full form (saved libraries) would not fit a replay link.
    expect(
      jsonEncode(library.toJson()).length,
      greaterThan(SkillLibrary.maxReplayCharacters),
    );
    final json = library.toCompactJson();
    // Built-in descriptions may become editable: count 160 more characters per override.
    for (final entry in (json['overrides'] as Map).values) {
      (entry as Map)['description'] = text;
    }
    final source = jsonEncode(json);
    final encoded = library.encodeReplay()!;
    // ignore: avoid_print
    print(
      'full ${jsonEncode(library.toJson()).length}, compact '
      '${jsonEncode(library.toCompactJson()).length}, with descriptions '
      '${source.length}, encoded ${encoded.length}',
    );
    expect(source.length, lessThan(30000));
    final decoded = SkillLibrary.decodeReplay(encoded)!;
    expect(jsonEncode(decoded.toJson()), jsonEncode(library.toJson()));
  });

  test(
    'the match draws the global sprite sizes while the switches are off',
    () {
      MatchSimulationController match(SkillLibrary library) =>
          MatchSimulationController(
            const [
              CustomBall(
                id: 'a',
                name: 'A',
                primaryColor: Colors.red,
                glowColor: Colors.pink,
              ),
              CustomBall(
                id: 'b',
                name: 'B',
                primaryColor: Colors.blue,
                glowColor: Colors.cyan,
              ),
            ],
            arenaRadius: 260,
            seed: 1,
            mode: MatchMode.arsenal,
            lookAhead: false,
            skillLibrary: library,
          );
      final own = SkillLibrary.defaults.applyToAll(
        tuning,
        weaponDisplayScale: 2,
        pickupDisplayScale: 1.5,
        effectDisplayScale: 0.5,
      );
      var p = match(own).powerUps!;
      expect(p.weaponDisplayScale(PowerUpKind.pistol), 2);
      expect(p.pickupDisplayScale(PowerUpKind.apple), 1.5);
      expect(p.effectDisplayScale(PowerUpKind.molotov), 0.5);
      p = match(
        own.withGlobal(
          weaponDisplayScale: 1.25,
          skillsSetWeaponDisplayScale: false,
          pickupDisplayScale: 0.75,
          skillsSetPickupDisplayScale: false,
          effectDisplayScale: 2.5,
          skillsSetEffectDisplayScale: false,
        ),
      ).powerUps!;
      expect(p.weaponDisplayScale(PowerUpKind.pistol), 1.25);
      expect(p.pickupDisplayScale(PowerUpKind.apple), 0.75);
      expect(p.effectDisplayScale(PowerUpKind.molotov), 2.5);
    },
  );

  test('compact snapshots read back as the same library; old full ones too', () {
    final library = SkillLibrary.defaults
        .withDefinition(
          SkillLibrary.defaults
              .builtIn(PowerUpKind.pistol, tuning)
              .copyWith(yell: '', weaponDisplayScale: 2, homing: true),
          tuning,
        )
        .withDefinition(
          SkillLibrary.defaults
              .builtIn(PowerUpKind.shotgun, tuning)
              .copyWith(projectileCount: 9, spreadDegrees: 60),
          tuning,
        );
    final compact = library.toCompactJson();
    expect(compact['version'], SkillLibrary.compactVersion);
    final pistol = (compact['overrides'] as Map)['builtin.pistol'] as Map;
    expect(pistol.keys.toSet(), {
      'id',
      'name',
      'base',
      'weapon_display_scale',
      'homing',
      'yell',
    });
    // The default has a yell and this override has none: written as null.
    expect(pistol['yell'], isNull);
    // Saved libraries keep the full form and today's version.
    expect(library.toJson()['version'], SkillLibrary.currentVersion);
    // As the full form reads back (an empty built-in yell is restored, as always).
    final expected = jsonEncode(
      SkillLibrary.fromJson(jsonDecode(jsonEncode(library.toJson()))).toJson(),
    );
    expect(jsonEncode(SkillLibrary.fromJson(compact).toJson()), expected);
    expect(
      jsonEncode(SkillLibrary.importJson(jsonEncode(compact)).toJson()),
      expected,
    );
    // A link made before the compact form: version 2, full overrides.
    final oldLink = base64Url
        .encode(utf8.encode(jsonEncode(library.toJson())))
        .replaceAll('=', '');
    expect(jsonEncode(SkillLibrary.decodeReplay(oldLink)!.toJson()), expected);
    expect(
      jsonEncode(SkillLibrary.decodeReplay(_oldPistolLink)!.toJson()),
      jsonEncode(
        SkillLibrary.defaults
            .withDefinition(
              SkillLibrary.defaults
                  .builtIn(PowerUpKind.pistol, tuning)
                  .copyWith(yell: 'PEW!'),
              tuning,
            )
            .toJson(),
      ),
    );
  });
}

/// A replay snapshot made before the compact form (version 2, full override): the pistol yelling "PEW!".
const _oldPistolLink =
    'eyJ2ZXJzaW9uIjoyLCJvdmVycmlkZXMiOnsiYnVpbHRpbi5waXN0b2wiOnsiaWQiOiJidWlsdGluLnBpc3RvbCIsIm5hbWUiOiJQaXN0b2wiLCJiYXNlIjoicGlzdG9sIiwiY2F0ZWdvcnkiOiJ3ZWFwb24iLCJlbmFibGVkIjp0cnVlLCJjdXN0b20iOmZhbHNlLCJhcnNlbmFsX2RhbWFnZSI6MTAuMCwiYWxsX291dF9kYW1hZ2UiOjgsInByb2plY3RpbGVfc3BlZWQiOjEuMiwicmFuZ2UiOjAuNTUsInByb2plY3RpbGVfc2l6ZSI6MS4wLCJwcm9qZWN0aWxlX3NwaW4iOjAuMCwiaG9taW5nIjpmYWxzZSwicmV0dXJuc190b19vcmlnaW4iOmZhbHNlLCJ0cmFja19uZWFyZXN0X29wcG9uZW50IjpmYWxzZSwid2VhcG9uX2Rpc3BsYXlfc2NhbGUiOjEuMCwicGlja3VwX2Rpc3BsYXlfc2NhbGUiOjEuMCwiZWZmZWN0X2Rpc3BsYXlfc2NhbGUiOjEuMCwid2VhcG9uX2dyaXBfaW5zZXQiOjAuMCwiZWZmZWN0X3N0cmVuZ3RoIjoxLjAsImhlYWxpbmciOjEwLjAsInNoaWVsZF9oaXRzIjoxLCJmcm96ZW5fZGFtYWdlX211bHRpcGxpZXIiOjEuNSwiZnJvemVuX2NvbGxpc2lvbl9kYW1hZ2UiOjUuMCwia25vY2tiYWNrIjowLjAsInNwcml0ZV9tb2RlIjoic3ByaXRlIiwiZWZmZWN0X21vZGUiOiJzcHJpdGUiLCJ1c2VfZ2xvYmFsX2VmZmVjdF92aXN1YWxzIjp0cnVlLCJzb3VuZF9jdWUiOiJzaG90IiwicmVwZWF0X2NvdW50IjoxLCJyZXBlYXRfaW50ZXJ2YWxfc2Vjb25kcyI6MC41LCJzdGFydF9kZWxheV9zZWNvbmRzIjowLjAsInRpY2tfaW50ZXJ2YWxfc2Vjb25kcyI6MC41LCJjb29sZG93bl9zZWNvbmRzIjowLjAsInRyaWdnZXJfaW50ZXJ2YWxfc2Vjb25kcyI6NS4wLCJlZmZlY3RfY29sb3IiOjQyOTQ5MjkyNTksInNwcml0ZV90aW50Ijo0Mjk0OTY3Mjk1LCJzY3JlZW5fc2hha2UiOjAuMTYsImhhbmRlZG5lc3MiOiJjYXJyaWVyRGVmYXVsdCIsInllbGwiOiJQRVchIiwiY2FsbG91dF9zdHlsZSI6Im5vcm1hbCIsImJ1YmJsZV90eXBlIjoic2hvdXQiLCJidWJibGVfZHVyYXRpb25fc2Vjb25kcyI6MS4yLCJleHBsb2Rlc19vbl9pbXBhY3QiOmZhbHNlLCJoYW5kX2VmZmVjdF9zY2FsZSI6MS4wLCJoYW5kX2VmZmVjdF9jb2xvciI6NDI5NDk2NzI5NSwiaGFuZF9lZmZlY3RfZHVyYXRpb25fc2Vjb25kcyI6MC42NX19LCJjdXN0b20iOltdfQ';
