import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_spawn_selector.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/match_setup/domain/rarity_preset.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  const legacy = PowerUpConfig.defaults;
  final balanced = RarityPreset.balanced.resolve(
    RarityWeights.fromTuning(legacy),
  );
  test('approved presets never change the legacy tuning defaults', () {
    expect(RarityPreset.casual.resolve(balanced).values, [35, 30, 20, 15]);
    expect(balanced.values, [40, 30, 20, 10]);
    expect(RarityPreset.competitive.resolve(balanced).values, [50, 30, 15, 5]);
    expect(RarityPreset.custom.resolve(balanced), same(balanced));
    expect(RarityWeights.fromTuning(legacy).values, [50, 45, 40, 35]);
  });
  test('custom validation rejects bad numbers and all-zero weights', () {
    for (final values in [
      ['0', '0', '0', '0'],
      ['NaN', '1', '2', '3'],
      ['-1', '2', '3', '4'],
      ['101', '2', '3', '4'],
      ['', '2', '3', '4'],
      ['1'],
    ]) {
      expect(RarityWeights.parse(values), isNull, reason: '$values');
    }
    expect(RarityWeights.parse(['0', '0', '1.5', '0'])!.values, [0, 0, 1.5, 0]);
  });
  test(
    'weights freeze into tuning and all four are explicit in replay encoding',
    () {
      final admin = legacy
          .withValue('dmg.pistol', 7)
          .withRarity(PowerUpKind.pistol, PowerUpRarity.special);
      final resolved = balanced.applyTo(admin);
      expect(RarityWeights.fromTuning(admin).values, [50, 45, 40, 35]);
      expect(resolved.arenaDamage(PowerUpKind.pistol), 7);
      expect(resolved.rarityOf(PowerUpKind.pistol), PowerUpRarity.special);
      final restored = PowerUpConfig.decode(resolved.encode()!)!;
      expect(RarityWeights.fromTuning(restored).values, balanced.values);
      final json =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(legacy.encode()!)),
                ),
              )
              as Map;
      for (final tier in PowerUpRarity.values) {
        expect(json.containsKey('rarity.${tier.name}'), isTrue);
      }
      final old = base64Url.encode(utf8.encode('{}'));
      expect(RarityWeights.fromTuning(PowerUpConfig.decode(old)!).values, [
        50,
        45,
        40,
        35,
      ]);
    },
  );
  test('preview distinguishes conditional odds from trap-inclusive odds', () {
    final odds = RaritySpawnOdds.calculate(
      tuning: balanced.applyTo(legacy),
      library: SkillLibrary.defaults,
    );
    final trapShare =
        PowerUpKind.values.where((k) => k.isTrap).length /
        PowerUpKind.values.length;
    expect(odds.traps, trapShare);
    expect(odds.nonTrap[PowerUpRarity.normal], .4);
    expect(
      odds.allSpawns[PowerUpRarity.normal],
      closeTo(.4 * (1 - trapShare), 1e-12),
    );
    final before = RaritySpawnOdds.calculate(
      tuning: balanced.applyTo(legacy),
      library: SkillLibrary.defaults,
      includeTraps: false,
    );
    expect(before.traps, 0);
    expect(before.nonTrap, before.allSpawns);
  });
  test(
    'preview excludes empty and zero tiers, retaining independent custom tiers',
    () {
      final source = SkillLibrary.defaults.builtIn(PowerUpKind.pistol, legacy);
      final variant = SkillLibrary.withOwnRarity(
        SkillLibrary.defaults.duplicate(source, 'Special Pistol'),
        PowerUpRarity.special,
        legacy,
      );
      final library = SkillLibrary.defaults.withDefinition(variant, legacy);
      final odds = RaritySpawnOdds.calculate(
        tuning: balanced.applyTo(legacy),
        library: library,
        builtIns: {PowerUpKind.knife},
      );
      expect(odds.nonTrap[PowerUpRarity.normal], .8);
      expect(odds.nonTrap[PowerUpRarity.special], .2);
      expect(odds.nonTrap[PowerUpRarity.rare], 0);
      final off = RaritySpawnOdds.calculate(
        tuning: balanced.applyTo(legacy),
        library: library,
        builtIns: {PowerUpKind.knife},
        customIds: {},
      );
      expect(off.nonTrap[PowerUpRarity.normal], 1);
      final unavailable = RaritySpawnOdds.calculate(
        tuning: RarityWeights([0, 1, 0, 0]).applyTo(legacy),
        library: SkillLibrary.defaults,
        builtIns: {PowerUpKind.knife},
      );
      expect(unavailable.hasPickups, isTrue);
      expect(unavailable.weighted, isFalse);
    },
  );
  test(
    'actual seeded selector tracks preview without weighting by item count',
    () {
      final tuning = balanced.applyTo(legacy);
      for (final kinds in [
        [
          PowerUpKind.pistol,
          PowerUpKind.shotgun,
          PowerUpKind.gatling,
          PowerUpKind.sniperRifle,
        ],
        [
          PowerUpKind.pistol,
          PowerUpKind.knife,
          PowerUpKind.apple,
          PowerUpKind.shotgun,
          PowerUpKind.gatling,
          PowerUpKind.sniperRifle,
        ],
      ]) {
        final random = SeededRandom(72);
        final counts = {for (final tier in PowerUpRarity.values) tier: 0};
        for (var i = 0; i < 20000; i++) {
          final kind = PowerUpSpawnSelector.choose(kinds, tuning, random);
          counts[tuning.rarityOf(kind)!] = counts[tuning.rarityOf(kind)!]! + 1;
        }
        for (final tier in PowerUpRarity.values) {
          expect(
            counts[tier]! / 20000,
            closeTo(balanced.values[tier.index] / 100, .015),
          );
        }
      }
    },
  );
  test('resolving unchanged legacy weights preserves every seeded draw', () {
    final resolved = RarityWeights.fromTuning(legacy).applyTo(legacy);
    final first = SeededRandom(92), second = SeededRandom(92);
    for (var i = 0; i < 1000; i++) {
      expect(
        PowerUpSpawnSelector.choose(PowerUpKind.values, resolved, first),
        PowerUpSpawnSelector.choose(PowerUpKind.values, legacy, second),
      );
    }
  });
}
