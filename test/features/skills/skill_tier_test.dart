import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_spawn_selector.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _balls = [
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
];

/// Every pickup that spawns in [seconds] of a still match: (kind, skill id).
List<(PowerUpKind, String?)> _spawns(
  SkillLibrary library, {
  int seed = 3,
  int seconds = 90,
}) {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: seed,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: library,
  );
  final seen = <(PowerUpKind, String?)>[];
  final known = <Object>{};
  for (var i = 0; i < seconds * 60; i++) {
    for (final ball in c.state.balls) {
      ball.velocity = Offset.zero;
    }
    c.tick(1 / 60);
    for (final p in c.powerUps!.field) {
      if (known.add(p)) seen.add((p.kind, p.skillId));
    }
  }
  return seen;
}

void main() {
  const tuning = PowerUpConfig.defaults;
  final kutsilyo = SkillLibrary.defaults.create('Kutsilyo', PowerUpKind.knife);

  test('a custom skill without its own tier follows its base kind', () {
    expect(kutsilyo.rarity, isNull);
    expect(SkillLibrary.rarityOf(kutsilyo, tuning), PowerUpRarity.normal);
    final epicKnives = tuning.withRarity(PowerUpKind.knife, PowerUpRarity.epic);
    expect(SkillLibrary.rarityOf(kutsilyo, epicKnives), PowerUpRarity.epic);
    // Built-ins always read the tuning.
    final knife = SkillLibrary.defaults.builtIn(PowerUpKind.knife, tuning);
    expect(SkillLibrary.rarityOf(knife, epicKnives), PowerUpRarity.epic);
  });

  test(
    'Kutsilyo set to Special leaves the built-in Knife Normal, and the other way round',
    () {
      final special = SkillLibrary.withOwnRarity(
        kutsilyo,
        PowerUpRarity.special,
        tuning,
      );
      expect(special.rarity, PowerUpRarity.special);
      expect(SkillLibrary.rarityOf(special, tuning), PowerUpRarity.special);
      final library = SkillLibrary.defaults.withDefinition(special, tuning);
      expect(tuning.rarityOf(PowerUpKind.knife), PowerUpRarity.normal);
      expect(
        SkillLibrary.rarityOf(
          library.builtIn(PowerUpKind.knife, tuning),
          tuning,
        ),
        PowerUpRarity.normal,
      );
      // Changing the built-in Knife keeps Kutsilyo's own tier.
      final rareKnives = tuning.withRarity(
        PowerUpKind.knife,
        PowerUpRarity.rare,
      );
      expect(
        SkillLibrary.rarityOf(library.custom.single, rareKnives),
        PowerUpRarity.special,
      );
    },
  );

  test(
    'the callout style follows a new tier unless it was set apart from the tier',
    () {
      expect(kutsilyo.calloutStyle, SkillCalloutStyle.normal);
      final special = SkillLibrary.withOwnRarity(
        kutsilyo,
        PowerUpRarity.special,
        tuning,
      );
      expect(special.calloutStyle, SkillCalloutStyle.special);
      final own = kutsilyo.copyWith(calloutStyle: SkillCalloutStyle.epic);
      expect(
        SkillLibrary.withOwnRarity(
          own,
          PowerUpRarity.special,
          tuning,
        ).calloutStyle,
        SkillCalloutStyle.epic,
      );
    },
  );

  test(
    'the own tier travels in JSON and replay snapshots; built-ins never keep one',
    () {
      final special = SkillLibrary.withOwnRarity(
        kutsilyo,
        PowerUpRarity.special,
        tuning,
      );
      expect(special.toJson()['rarity'], 'special');
      expect(kutsilyo.toJson().containsKey('rarity'), isFalse);
      expect(
        SkillDefinition.fromJson(special.toJson())!.rarity,
        PowerUpRarity.special,
      );
      final library = SkillLibrary.defaults.withDefinition(special, tuning);
      final replay = SkillLibrary.decodeReplay(library.encodeReplay()!)!;
      expect(replay.custom.single.rarity, PowerUpRarity.special);
      final builtIn = SkillLibrary.defaults
          .builtIn(PowerUpKind.knife, tuning)
          .copyWith(rarity: PowerUpRarity.epic)
          .validated();
      expect(builtIn.rarity, isNull);
    },
  );

  group('spawn weights', () {
    double share(SkillDefinition variant, {int draws = 20000}) {
      final rng = SeededRandom(77);
      var hits = 0;
      final library = SkillLibrary.defaults.withDefinition(variant, tuning);
      for (var i = 0; i < draws; i++) {
        final skill = PowerUpSpawnSelector.chooseSkill(
          const [PowerUpKind.knife, PowerUpKind.sniperRifle],
          tuning,
          rng,
          library: library,
          custom: library.custom,
        );
        if (skill.id == variant.id) hits++;
      }
      return hits / draws;
    }

    test('a custom skill spawns at its own tier, not its base kind', () {
      // Normal 50, Special 35: Kutsilyo shares the Special pick with the Sniper Rifle.
      expect(
        share(
          SkillLibrary.withOwnRarity(kutsilyo, PowerUpRarity.special, tuning),
        ),
        closeTo(35 / 85 / 2, 0.02),
      );
      // Rare 45 is a tier of its own here.
      expect(
        share(SkillLibrary.withOwnRarity(kutsilyo, PowerUpRarity.rare, tuning)),
        closeTo(45 / 130, 0.02),
      );
    });

    test(
      'a custom skill at its base tier shares the built-in pick as before',
      () {
        expect(share(kutsilyo), closeTo(50 / 85 / 2, 0.02));
      },
    );

    test('tiers equal to the base kind draw exactly as before', () {
      final follow = SkillLibrary.defaults.withDefinition(kutsilyo, tuning);
      final explicit = SkillLibrary.defaults.withDefinition(
        SkillLibrary.withOwnRarity(kutsilyo, PowerUpRarity.normal, tuning),
        tuning,
      );
      expect(
        PowerUpSpawnSelector.customTiersDiffer(follow.custom, tuning),
        isFalse,
      );
      expect(
        PowerUpSpawnSelector.customTiersDiffer(explicit.custom, tuning),
        isFalse,
      );
      expect(_spawns(explicit), _spawns(follow));
      expect(_spawns(follow, seed: 11), _spawns(explicit, seed: 11));
    });

    test(
      'a Special Kutsilyo spawns at another rate than a Normal one in a match',
      () {
        int count(SkillLibrary library) {
          var n = 0;
          for (final seed in [1, 2, 3, 4, 5, 6]) {
            n += _spawns(
              library,
              seed: seed,
              seconds: 120,
            ).where((s) => s.$2 == kutsilyo.id).length;
          }
          return n;
        }

        final normal = count(
          SkillLibrary.defaults.withDefinition(kutsilyo, tuning),
        );
        final special = count(
          SkillLibrary.defaults.withDefinition(
            SkillLibrary.withOwnRarity(kutsilyo, PowerUpRarity.special, tuning),
            tuning,
          ),
        );
        expect(normal, greaterThan(0));
        expect(special, isNot(normal));
      },
    );
  });
}
