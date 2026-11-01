import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tuning = PowerUpConfig.defaults;

  test('restoring one built-in preserves unrelated edits and custom skills', () {
    final original = SkillLibrary.defaults;
    final pistol = original.builtIn(PowerUpKind.pistol, tuning);
    final shotgun = original.builtIn(PowerUpKind.shotgun, tuning);
    final edited = original
        .withDefinition(pistol.copyWith(arsenalDamage: 99), tuning)
        .withDefinition(shotgun.copyWith(projectileCount: 7), tuning);
    expect(edited.hasBuiltInOverride(pistol.id), isTrue);
    expect(edited.hasBuiltInOverride(shotgun.id), isTrue);

    final restored = edited.restoreBuiltIn(pistol.id);
    expect(restored.hasBuiltInOverride(pistol.id), isFalse);
    expect(restored.hasBuiltInOverride(shotgun.id), isTrue);
    expect(restored.builtIn(PowerUpKind.pistol, tuning).arsenalDamage,
        pistol.arsenalDamage);
    expect(restored.builtIn(PowerUpKind.shotgun, tuning).projectileCount, 7);
    expect(restored.restoreBuiltIn(pistol.id), same(restored));
    expect(edited.hasBuiltInOverride(pistol.id), isTrue);
  });

  test('restore ignores custom and unknown IDs', () {
    final library = SkillLibrary.defaults;
    expect(library.restoreBuiltIn('custom.example'), same(library));
    expect(library.restoreBuiltIn('builtin.nonexistent'), same(library));
  });

  test('restored built-in stays restored after JSON round-trip', () {
    final pistol = SkillLibrary.defaults.builtIn(PowerUpKind.pistol, tuning);
    final library = SkillLibrary.defaults
        .withDefinition(pistol.copyWith(arsenalDamage: 123), tuning)
        .restoreBuiltIn(pistol.id);
    final loaded = SkillLibrary.fromJson(library.toJson());
    expect(loaded.hasBuiltInOverride(pistol.id), isFalse);
    expect(loaded.builtIn(PowerUpKind.pistol, tuning).arsenalDamage,
        pistol.arsenalDamage);
  });
}
