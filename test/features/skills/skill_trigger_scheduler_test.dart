import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/skill_trigger_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = SkillDefinition(
    id: 'custom.scheduler', name: 'Scheduler', custom: true,
    baseKind: PowerUpKind.pistol, category: SkillCategory.weapon,
    trigger: SkillTrigger.damageTaken,
  );

  test('rejected activation retries on next simulation frame', () {
    final scheduler = SkillTriggerScheduler(base);
    expect(scheduler.signal(SkillTrigger.damageTaken, 0), isTrue);
    expect(scheduler.advance(0), [0]);
    expect(scheduler.retryRejected(0), isTrue);
    expect(scheduler.advance(0), isEmpty);
    expect(scheduler.advance(1 / 60), [1 / 60]);
  });

  test('duplicate rejected activations do not multiply retries', () {
    final scheduler = SkillTriggerScheduler(base);
    expect(scheduler.retryRejected(0), isTrue);
    expect(scheduler.retryRejected(0), isTrue);
    expect(scheduler.pendingCount, 1);
  });

  test('retries reject nonfinite and backwards timestamps', () {
    final scheduler = SkillTriggerScheduler(base);
    scheduler.advance(3);
    expect(() => scheduler.retryRejected(2), throwsArgumentError);
    expect(() => scheduler.retryRejected(double.infinity), throwsArgumentError);
  });

  test('retry at unrepresentable time is rejected safely', () {
    final scheduler = SkillTriggerScheduler(base);
    expect(scheduler.retryRejected(double.maxFinite), isFalse);
    expect(scheduler.pendingCount, 0);
  });

  test('matching event schedules activation, other events do not', () {
    final scheduler = SkillTriggerScheduler(base);
    expect(scheduler.signal(SkillTrigger.elimination, 0), isFalse);
    expect(scheduler.signal(SkillTrigger.damageTaken, 0), isTrue);
    expect(scheduler.advance(0), [0]);
  });

  test('cooldown suppresses triggers until ready', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(cooldownSeconds: 3));
    expect(scheduler.signal(SkillTrigger.damageTaken, 0), isTrue);
    expect(scheduler.signal(SkillTrigger.damageTaken, 2), isFalse);
    expect(scheduler.signal(SkillTrigger.damageTaken, 3), isTrue);
    expect(scheduler.advance(3), [0, 3]);
  });

  test('delays and repeats are emitted in chronological order', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      startDelaySeconds: 1, repeatCount: 3, repeatIntervalSeconds: 0.5,
    ));
    scheduler.signal(SkillTrigger.damageTaken, 0);
    expect(scheduler.advance(0.9), isEmpty);
    expect(scheduler.advance(1.5), [1, 1.5]);
    expect(scheduler.advance(2), [2]);
  });

  test('timer catches up across skipped frames', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      trigger: SkillTrigger.timer, triggerIntervalSeconds: 2,
    ));
    expect(scheduler.advance(1), isEmpty);
    expect(scheduler.advance(6), [2, 4, 6]);
  });

  test('reset clears pending and restores timer schedule', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      trigger: SkillTrigger.timer, triggerIntervalSeconds: 2,
    ));
    scheduler.advance(3);
    scheduler.reset();
    expect(scheduler.advance(2), [2]);
  });

  test('cancellation clears queued repeat activations', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(repeatCount: 3));
    scheduler.signal(SkillTrigger.damageTaken, 0);
    scheduler.cancelPending();
    expect(scheduler.advance(3), isEmpty);
  });

  test('rejects backwards and nonfinite timestamps', () {
    final scheduler = SkillTriggerScheduler(base);
    scheduler.advance(2);
    expect(() => scheduler.advance(1), throwsArgumentError);
    expect(() => scheduler.advance(double.nan), throwsArgumentError);
  });
  test('pending queue is bounded under rapid repeated triggers', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      repeatCount: 128, repeatIntervalSeconds: 100,
    ));
    for (var i = 0; i < 8; i++) {
      expect(scheduler.signal(SkillTrigger.damageTaken, i.toDouble()), isTrue);
    }
    expect(scheduler.signal(SkillTrigger.damageTaken, 8), isFalse);
    expect(scheduler.pendingActivationCount,
        SkillTriggerScheduler.maxPendingActivations);
    scheduler.cancelPending();
    expect(scheduler.pendingActivationCount, 0);
  });

  test('nonfinite timer interval does not hang the scheduler', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      trigger: SkillTrigger.timer, triggerIntervalSeconds: double.infinity,
    ));
    expect(scheduler.advance(0.01), isNotEmpty);
  });

  test('nonfinite cooldown cannot permanently lock a trigger', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      cooldownSeconds: double.infinity,
    ));
    expect(scheduler.signal(SkillTrigger.damageTaken, 0), isTrue);
    expect(scheduler.signal(SkillTrigger.damageTaken, 1), isTrue);
    expect(scheduler.advance(1), [0, 1]);
  });

  test('rejects an event atomically when repeat queue is full', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      repeatCount: 128, repeatIntervalSeconds: 100,
    ));
    for (var i = 0; i < 8; i++) {
      expect(scheduler.signal(SkillTrigger.damageTaken, i.toDouble()), isTrue);
    }
    expect(scheduler.pendingCount, SkillTriggerScheduler.maxPendingActivations);
    expect(scheduler.signal(SkillTrigger.damageTaken, 8), isFalse);
    expect(scheduler.pendingCount, SkillTriggerScheduler.maxPendingActivations);
    scheduler.cancelPending();
    expect(scheduler.signal(SkillTrigger.damageTaken, 9), isTrue);
  });

  test('failed queue admission does not consume cooldown', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      repeatCount: 128, repeatIntervalSeconds: 100, cooldownSeconds: 0.5,
    ));
    for (var i = 0; i < 8; i++) {
      expect(scheduler.signal(SkillTrigger.damageTaken, i.toDouble()), isTrue);
    }
    expect(scheduler.signal(SkillTrigger.damageTaken, 8), isFalse);
    scheduler.cancelPending();
    expect(scheduler.signal(SkillTrigger.damageTaken, 8), isTrue);
  });

  test('timer backpressure does not exceed queue limit', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      trigger: SkillTrigger.timer, triggerIntervalSeconds: 0.01,
      repeatCount: 128, repeatIntervalSeconds: 100,
    ));
    scheduler.advance(0.2);
    expect(scheduler.pendingCount, lessThanOrEqualTo(
      SkillTriggerScheduler.maxPendingActivations));
  });

  test('nonfinite start delay does not schedule at infinity', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      startDelaySeconds: double.infinity,
    ));
    expect(scheduler.signal(SkillTrigger.damageTaken, 0), isTrue);
    expect(scheduler.advance(0), [0]);
  });

  test('queue overflow does not drop existing activations', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      repeatCount: 128, repeatIntervalSeconds: 10,
    ));
    for (var i = 0; i < 8; i++) {
      expect(scheduler.signal(SkillTrigger.damageTaken, i.toDouble()), isTrue);
    }
    expect(scheduler.signal(SkillTrigger.damageTaken, 8), isFalse);
    expect(scheduler.advance(8), isNotEmpty);
  });

  test('nonfinite interval is normalized safely', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      trigger: SkillTrigger.timer, triggerIntervalSeconds: double.nan,
    ));
    expect(scheduler.advance(0.01), isNotEmpty);
  });

  test('repeat overflow is rejected without reserving partial slots', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      startDelaySeconds: 1e308, repeatCount: 3,
      repeatIntervalSeconds: 1e308,
    ));
    expect(scheduler.signal(SkillTrigger.damageTaken, 0), isFalse);
    expect(scheduler.pendingCount, 0);
  });

  test('overflowed cooldown does not allow premature reactivation', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      cooldownSeconds: 1e308,
    ));
    expect(scheduler.signal(SkillTrigger.damageTaken, 1e308), isTrue);
    expect(scheduler.signal(SkillTrigger.damageTaken, 1.1e308), isFalse);
    expect(scheduler.signal(SkillTrigger.damageTaken, double.maxFinite), isTrue);
  });

  test('timer remains bounded at very large match timestamps', () {
    final scheduler = SkillTriggerScheduler(base.copyWith(
      trigger: SkillTrigger.timer, triggerIntervalSeconds: 1e308,
    ));
    expect(scheduler.advance(1e308), [1e308]);
    expect(scheduler.nextTimerAt, isNull);
    expect(scheduler.advance(1.1e308), isEmpty);
  });

}
