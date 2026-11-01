import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/skill_trigger_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const skill = SkillDefinition(
    id: 'custom.passive_gate',
    name: 'Passive Gate',
    custom: true,
    baseKind: PowerUpKind.pistol,
    category: SkillCategory.weapon,
    trigger: SkillTrigger.damageTaken,
    cooldownSeconds: 2,
    startDelaySeconds: 1,
    repeatCount: 3,
  );

  test('passive gate delegates delay and repeats to the effect executor', () {
    final gate = SkillTriggerScheduler(skill.copyWith(
      cooldownSeconds: 0,
      startDelaySeconds: 0,
      repeatCount: 1,
    ));
    expect(gate.signal(SkillTrigger.damageTaken, 1), isTrue);
    expect(gate.advance(1), [1]);
    expect(gate.advance(1.1), isEmpty);
  });

  test('rejected damage event can retry without another signal', () {
    final gate = SkillTriggerScheduler(skill.copyWith(
      cooldownSeconds: 0, startDelaySeconds: 0, repeatCount: 1,
    ));
    expect(gate.signal(SkillTrigger.damageTaken, 1), isTrue);
    expect(gate.advance(1), [1]);
    expect(gate.retryRejected(1), isTrue);
    expect(gate.pendingCount, 1);
    expect(gate.advance(1 + 1 / 60), hasLength(1));
    expect(gate.pendingCount, 0);
  });

  test('cancelPending removes all retries after elimination', () {
    final gate = SkillTriggerScheduler(skill.copyWith(
      cooldownSeconds: 0, startDelaySeconds: 0, repeatCount: 1,
    ));
    expect(gate.signal(SkillTrigger.damageTaken, 1), isTrue);
    expect(gate.advance(1), [1]);
    expect(gate.retryRejected(1), isTrue);
    gate.cancelPending();
    expect(gate.pendingCount, 0);
    expect(gate.advance(2), isEmpty);
  });

  test('timer gate advances at match-clock seconds', () {
    final gate = SkillTriggerScheduler(skill.copyWith(
      trigger: SkillTrigger.timer,
      triggerIntervalSeconds: 1,
      cooldownSeconds: 0,
      startDelaySeconds: 0,
      repeatCount: 1,
    ));
    expect(gate.advance(59 / 60), isEmpty);
    expect(gate.advance(60 / 60), [1]);
    expect(gate.advance(120 / 60), [2]);
  });
}
