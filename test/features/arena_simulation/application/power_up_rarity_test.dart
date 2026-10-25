import 'dart:convert';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_spawn_selector.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all pickups have tiers and requested powerful weapons default to Epic', () {
    for (final kind in PowerUpKind.values) {
      expect(PowerUpConfig.defaults.rarityOf(kind), kind.isTrap ? isNull : isNotNull);
    }
    expect(PowerUpKind.rocketLauncher.rarity, PowerUpRarity.epic);
    expect(PowerUpKind.omegaTendrils.rarity, PowerUpRarity.epic);
  });

  test('seeded selection follows 50/30/20 across enabled pickup tiers', () {
    final rng = SeededRandom(123);
    final items = PowerUpKind.values.where((kind) => !kind.isTrap).toList();
    final counts = {for (final rarity in PowerUpRarity.values) rarity: 0};
    for (var i = 0; i < 20000; i++) {
      final kind = PowerUpSpawnSelector.choose(items, PowerUpConfig.defaults, rng);
      counts[kind.rarity!] = counts[kind.rarity!]! + 1;
    }
    expect(counts[PowerUpRarity.normal]! / 20000, closeTo(0.5, 0.02));
    expect(counts[PowerUpRarity.rare]! / 20000, closeTo(0.3, 0.02));
    expect(counts[PowerUpRarity.epic]! / 20000, closeTo(0.2, 0.02));
  });

  test('empty tiers redistribute and admin classifications drive selection', () {
    final config = PowerUpConfig.defaults.withRarity(PowerUpKind.pistol, PowerUpRarity.epic);
    expect(config.rarityOf(PowerUpKind.pistol), PowerUpRarity.epic);
    final replayJson = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(config.encode()!)))) as Map;
    expect((replayJson['_tiers'] as String)[PowerUpKind.pistol.index], '${PowerUpRarity.epic.index}');
    expect((replayJson['_tiers'] as String)[PowerUpKind.rocketLauncher.index], '${PowerUpRarity.epic.index}');
    expect(replayJson['rarity.normal'], 50);
    expect(PowerUpConfig.decode(config.encode()!), config);
    expect(PowerUpConfig.fromJson(config.toJson()), config);
    final rng = SeededRandom(8);
    for (var i = 0; i < 100; i++) {
      expect(PowerUpSpawnSelector.choose([PowerUpKind.pistol], config, rng), PowerUpKind.pistol);
    }
  });

  test('traps retain their separate share after deployment is enabled', () {
    final rng = SeededRandom(456);
    var traps = 0;
    for (var i = 0; i < 20000; i++) {
      if (PowerUpSpawnSelector.choose(PowerUpKind.values, PowerUpConfig.defaults, rng).isTrap) traps++;
    }
    expect(traps / 20000, closeTo(6 / 44, 0.02));
  });


  test('rarity selection remains deterministic for the same seed', () {
    final a = SeededRandom(12);
    final b = SeededRandom(12);
    for (var i = 0; i < 1000; i++) {
      expect(PowerUpSpawnSelector.choose(PowerUpKind.values, PowerUpConfig.defaults, a),
          PowerUpSpawnSelector.choose(PowerUpKind.values, PowerUpConfig.defaults, b));
    }
  });
}
