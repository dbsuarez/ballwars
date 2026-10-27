import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  const tuning = PowerUpConfig.defaults;
  final skill = SkillLibrary.defaults
      .create('Loud', PowerUpKind.pistol)
      .copyWith(bubbleDurationSeconds: 3, screenShake: 0.9);

  test('by default each skill uses its own callout duration and screen shake', () {
    const library = SkillLibrary.defaults;
    expect(library.skillsSetCallout, isTrue);
    expect(library.skillsSetScreenShake, isTrue);
    expect(library.calloutSecondsFor(skill), 3);
    expect(library.screenShakeFor(skill), 0.9);
    expect(library.isDefault, isTrue);
  });

  test('switched off, every skill uses the global values', () {
    final library = SkillLibrary.defaults.withGlobal(
      calloutSeconds: 2,
      skillsSetCallout: false,
      screenShake: 0.1,
      skillsSetScreenShake: false,
    );
    expect(library.calloutSecondsFor(skill), 2);
    expect(library.screenShakeFor(skill), 0.1);
    expect(library.isDefault, isFalse);
    // Clamped to their ranges.
    expect(SkillLibrary.defaults.withGlobal(calloutSeconds: 99).calloutSeconds, 10);
    expect(SkillLibrary.defaults.withGlobal(screenShake: 5).screenShake, 1);
  });

  test('the global values are saved, kept through skill edits, and replayed', () {
    final library = SkillLibrary.defaults
        .withGlobal(calloutSeconds: 2.5, skillsSetCallout: false, screenShake: 0.6, skillsSetScreenShake: false)
        .withDefinition(skill, tuning);
    final removed = library.removeCustom(skill.id);
    for (final l in [library, removed, SkillLibrary.fromJson(library.toJson()), SkillLibrary.decodeReplay(library.encodeReplay()!)!]) {
      expect(l.calloutSeconds, 2.5);
      expect(l.skillsSetCallout, isFalse);
      expect(l.screenShake, 0.6);
      expect(l.skillsSetScreenShake, isFalse);
    }
    // Older saved libraries have neither: each skill sets its own, as before.
    final old = SkillLibrary.fromJson({'version': 2, 'overrides': {}, 'custom': []});
    expect(old.skillsSetCallout, isTrue);
    expect(old.skillsSetScreenShake, isTrue);
  });
}
