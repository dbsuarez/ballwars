import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_behavior_diagnostics.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = SkillDefinition(id: 'custom.behavior-test', name: 'Test',
      baseKind: PowerUpKind.pistol, custom: true);

  test('legacy defaults remain valid and warnings do not mutate definitions', () {
    expect(SkillBehaviorDiagnostics.warnings(base), isEmpty);
    expect(base.delivery, isNull);
  });

  test('warns about ignored projectile and area configuration', () {
    final skill = base.copyWith(
      delivery: SkillDelivery.instant,
      homing: true,
      returnsToOrigin: true,
      projectileCount: 3,
      areaRadiusRatio: 0.4,
    );
    final warnings = SkillBehaviorDiagnostics.warnings(skill);
    expect(warnings, hasLength(4));
    expect(warnings.any((warning) => warning.contains('Homing')), isTrue);
  });

  test('projectile delivery does not warn about homing or return', () {
    final skill = base.copyWith(delivery: SkillDelivery.projectile,
        homing: true, returnsToOrigin: true, projectileCount: 3);
    expect(SkillBehaviorDiagnostics.warnings(skill), isEmpty);
  });

  test('repeated activations require a positive interval', () {
    final skill = base.copyWith(repeatCount: 3, repeatIntervalSeconds: 0);
    expect(SkillBehaviorDiagnostics.warnings(skill).single,
        contains('repeat interval'));
  });
}
