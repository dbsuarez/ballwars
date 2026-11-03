import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';

void main() {
  test('legacy defaults keep both trap sources enabled', () {
    const config = PowerUpConfig.defaults;
    expect(config.arenaTrapsEnabled, isTrue);
    expect(config.skillTrapsEnabled, isTrue);
    expect(config.allTrapsDisabled, isFalse);
  });

  test('trap source switches operate independently', () {
    final arenaOff = PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0);
    expect(arenaOff.arenaTrapsEnabled, isFalse);
    expect(arenaOff.skillTrapsEnabled, isTrue);
    final skillsOff = PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0);
    expect(skillsOff.arenaTrapsEnabled, isTrue);
    expect(skillsOff.skillTrapsEnabled, isFalse);
  });

  test('master override wins and persisted values survive JSON', () {
    final original = PowerUpConfig.defaults
        .withValue('allTrapsDisabled', 1)
        .withValue('arenaTrapsEnabled', 1)
        .withValue('skillTrapsEnabled', 1);
    final restored = PowerUpConfig.fromJson(original.toJson());
    expect(restored.allTrapsDisabled, isTrue);
    expect(restored.arenaTrapsEnabled, isFalse);
    expect(restored.skillTrapsEnabled, isFalse);
  });
  test('arena-only mode remains enabled after serialization', () {
    final original = PowerUpConfig.defaults
        .withValue('arenaTrapsEnabled', 1)
        .withValue('skillTrapsEnabled', 0);
    final restored = PowerUpConfig.fromJson(original.toJson());
    expect(restored.arenaTrapsEnabled, isTrue);
    expect(restored.skillTrapsEnabled, isFalse);
  });

  test('skill-only mode remains enabled after serialization', () {
    final original = PowerUpConfig.defaults
        .withValue('arenaTrapsEnabled', 0)
        .withValue('skillTrapsEnabled', 1);
    final restored = PowerUpConfig.fromJson(original.toJson());
    expect(restored.arenaTrapsEnabled, isFalse);
    expect(restored.skillTrapsEnabled, isTrue);
  });

  test('trap controls survive replay link encoding and decoding', () {
    final original = PowerUpConfig.defaults
        .withValue('arenaTrapsEnabled', 0)
        .withValue('skillTrapsEnabled', 1)
        .withValue('allTrapsDisabled', 1);
    final encoded = original.encode();
    expect(encoded, isNotNull);
    final restored = PowerUpConfig.decode(encoded!);
    expect(restored, isNotNull);
    expect(restored!.allTrapsDisabled, isTrue);
    expect(restored.arenaTrapsEnabled, isFalse);
    expect(restored.skillTrapsEnabled, isFalse);
    // The underlying independent choices remain saved if the master is lifted.
    final lifted = restored.withValue('allTrapsDisabled', 0);
    expect(lifted.arenaTrapsEnabled, isFalse);
    expect(lifted.skillTrapsEnabled, isTrue);
  });

  test('all eight trap toggle combinations preserve underlying choices', () {
    for (final arena in [0, 1]) {
      for (final skill in [0, 1]) {
        for (final master in [0, 1]) {
          final configured = PowerUpConfig.defaults
              .withValue('arenaTrapsEnabled', arena)
              .withValue('skillTrapsEnabled', skill)
              .withValue('allTrapsDisabled', master);
          final restored = PowerUpConfig.fromJson(configured.toJson());
          expect(restored.allTrapsDisabled, master == 1);
          expect(restored.arenaTrapsEnabled, master == 0 && arena == 1);
          expect(restored.skillTrapsEnabled, master == 0 && skill == 1);
          final lifted = restored.withValue('allTrapsDisabled', 0);
          expect(lifted.arenaTrapsEnabled, arena == 1);
          expect(lifted.skillTrapsEnabled, skill == 1);
        }
      }
    }
  });

  test('legacy JSON without new trap keys preserves enabled defaults', () {
    final restored = PowerUpConfig.fromJson(<String, num>{});
    expect(restored.allTrapsDisabled, isFalse);
    expect(restored.arenaTrapsEnabled, isTrue);
    expect(restored.skillTrapsEnabled, isTrue);
  });

  test('master disable overrides enabled skill traps and restores on lift', () {
    final enabled = PowerUpConfig.defaults
        .withValue('arenaTrapsEnabled', 0)
        .withValue('skillTrapsEnabled', 1);
    expect(enabled.skillTrapsEnabled, isTrue);
    expect(enabled.arenaTrapsEnabled, isFalse);

    final disabled = enabled.withValue('allTrapsDisabled', 1);
    expect(disabled.skillTrapsEnabled, isFalse);
    expect(disabled.arenaTrapsEnabled, isFalse);

    final restored = PowerUpConfig.fromJson(disabled.toJson())
        .withValue('allTrapsDisabled', 0);
    expect(restored.skillTrapsEnabled, isTrue);
    expect(restored.arenaTrapsEnabled, isFalse);
  });

  test('replay links preserve all trap combinations and master precedence', () {
    for (final arena in [0, 1]) {
      for (final skill in [0, 1]) {
        for (final master in [0, 1]) {
          final configured = PowerUpConfig.defaults
              .withValue('arenaTrapsEnabled', arena)
              .withValue('skillTrapsEnabled', skill)
              .withValue('allTrapsDisabled', master);
          final encoded = configured.encode();
          expect(encoded, isNotNull);
          final decoded = PowerUpConfig.decode(encoded!);
          expect(decoded, isNotNull);
          expect(decoded!.allTrapsDisabled, master == 1);
          expect(decoded.arenaTrapsEnabled, master == 0 && arena == 1);
          expect(decoded.skillTrapsEnabled, master == 0 && skill == 1);
          final lifted = decoded.withValue('allTrapsDisabled', 0);
          expect(lifted.arenaTrapsEnabled, arena == 1);
          expect(lifted.skillTrapsEnabled, skill == 1);
        }
      }
    }
  });

}
