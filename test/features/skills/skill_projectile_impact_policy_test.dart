import 'package:ballwars/features/skills/domain/skill_activation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firing cooldown gates a new launch but not an existing shot impact', () {
    expect(SkillActivationGate.canActivate(
      currentStep: 10, readyStep: 120,
      hasTargetsOrIndependentEffects: true, hasScheduleCapacity: true,
    ), isFalse);
    expect(SkillActivationGate.canResolveProjectileImpact(
      hasTargetsOrIndependentEffects: true, hasScheduleCapacity: true,
    ), isTrue);
  });
  test('impact still requires targets or independent effects', () {
    expect(SkillActivationGate.canResolveProjectileImpact(
      hasTargetsOrIndependentEffects: false, hasScheduleCapacity: true,
    ), isFalse);
  });
  test('impact still honors scheduled effect capacity', () {
    expect(SkillActivationGate.canResolveProjectileImpact(
      hasTargetsOrIndependentEffects: true, hasScheduleCapacity: false,
    ), isFalse);
  });
}
