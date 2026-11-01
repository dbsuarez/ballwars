import 'package:ballwars/features/skills/domain/skill_activation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ready at expiry step, not before', () {
    final ready = SkillActivationGate.nextReadyStep(120, 1.5);
    expect(ready, 210);
    expect(SkillActivationGate.isReady(209, ready), isFalse);
    expect(SkillActivationGate.isReady(210, ready), isTrue);
  });

  test('zero cooldown does not delay another activation', () {
    expect(SkillActivationGate.nextReadyStep(15, 0), 15);
    expect(SkillActivationGate.isReady(15, 15), isTrue);
    expect(SkillActivationGate.isReady(0, null), isTrue);
  });

  test('fractional cooldown rounds up to avoid early activation', () {
    expect(SkillActivationGate.nextReadyStep(10, 0.011), 11);
    expect(SkillActivationGate.nextReadyStep(10, double.nan), 10);
  });
  test('rejects activation during cooldown without consuming resource', () {
    expect(SkillActivationGate.canActivate(
      currentStep: 119,
      readyStep: 120,
      hasTargetsOrIndependentEffects: true,
      hasScheduleCapacity: true,
    ), isFalse);
    expect(SkillActivationGate.canActivate(
      currentStep: 120,
      readyStep: 120,
      hasTargetsOrIndependentEffects: true,
      hasScheduleCapacity: true,
    ), isTrue);
  });

  test('rejects empty target selection', () {
    expect(SkillActivationGate.canActivate(
      currentStep: 0,
      hasTargetsOrIndependentEffects: false,
      hasScheduleCapacity: true,
    ), isFalse);
  });

  test('rejects exhausted schedule capacity', () {
    expect(SkillActivationGate.canActivate(
      currentStep: 0,
      hasTargetsOrIndependentEffects: true,
      hasScheduleCapacity: false,
    ), isFalse);
  });

  test('no cooldown and available capacity admits activation', () {
    expect(SkillActivationGate.canActivate(
      currentStep: 0,
      hasTargetsOrIndependentEffects: true,
      hasScheduleCapacity: true,
    ), isTrue);
  });

  test('cooldown gate rejects nonfinite durations safely', () {
    expect(SkillActivationGate.nextReadyStep(50, double.infinity), 50);
    expect(SkillActivationGate.nextReadyStep(50, double.negativeInfinity), 50);
  });

  test('capacity rejection remains independent of cooldown', () {
    expect(SkillActivationGate.canActivate(
      currentStep: 100,
      readyStep: 100,
      hasTargetsOrIndependentEffects: true,
      hasScheduleCapacity: false,
    ), isFalse);
  });

}
