import 'package:ballwars/features/skills/domain/skill_activation_gate.dart';
import 'package:ballwars/features/skills/domain/skill_projectile_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projectile impact admission is separate from firing', () {
    for (final readyStep in [1, 60, 600, 6000]) {
      test('shot can resolve while cooldown is active until step $readyStep', () {
        expect(SkillActivationGate.canActivate(
          currentStep: 0,
          readyStep: readyStep,
          hasTargetsOrIndependentEffects: true,
          hasScheduleCapacity: true,
        ), isFalse);
        expect(SkillActivationGate.canResolveProjectileImpact(
          hasTargetsOrIndependentEffects: true,
          hasScheduleCapacity: true,
        ), isTrue);
      });
    }
    test('impact does not acquire or advance a firing cooldown', () {
      final firingReady = SkillActivationGate.nextReadyStep(30, 2.5);
      expect(firingReady, 180);
      expect(SkillActivationGate.canResolveProjectileImpact(
        hasTargetsOrIndependentEffects: true,
        hasScheduleCapacity: true,
      ), isTrue);
      expect(SkillActivationGate.isReady(179, firingReady), isFalse);
      expect(SkillActivationGate.isReady(180, firingReady), isTrue);
    });
    for (final targets in [true, false]) {
      for (final capacity in [true, false]) {
        test('impact honors targets=$targets schedule=$capacity', () {
          expect(SkillActivationGate.canResolveProjectileImpact(
            hasTargetsOrIndependentEffects: targets,
            hasScheduleCapacity: capacity,
          ), targets && capacity);
        });
      }
    }
  });

  group('volley budget and symmetry', () {
    for (final count in [1, 2, 3, 4, 5, 12, 96]) {
      test('$count admitted shots span their configured spread', () {
        final offsets = [for (var i = 0; i < count; i++)
          SkillProjectileBudget.spreadOffset(
            index: i, admitted: count, spreadDegrees: 60,
          )];
        if (count == 1) {
          expect(offsets, [0]);
        } else {
          expect(offsets.first, closeTo(-30, 1e-10));
          expect(offsets.last, closeTo(30, 1e-10));
          for (var i = 0; i < count; i++) {
            expect(offsets[i], closeTo(-offsets[count - 1 - i], 1e-10));
          }
        }
      });
    }
    for (final available in [0, 1, 2, 3, 4, 5]) {
      test('only $available of 5 requested slots are admitted', () {
        final admitted = SkillProjectileBudget.admitted(
          active: 96 - available, requested: 5, limit: 96,
        );
        expect(admitted, available);
        if (admitted == 1) {
          expect(SkillProjectileBudget.spreadOffset(
            index: 0, admitted: admitted, spreadDegrees: 60,
          ), 0);
        }
      });
    }
    test('zero spread keeps every projectile on the aim axis', () {
      for (var i = 0; i < 20; i++) {
        expect(SkillProjectileBudget.spreadOffset(
          index: i, admitted: 20, spreadDegrees: 0,
        ), 0);
      }
    });
    test('invalid indices and nonfinite spreads are harmless', () {
      for (final spread in [double.nan, double.infinity, double.negativeInfinity]) {
        for (final i in [-2, 0, 1, 2, 3]) {
          expect(SkillProjectileBudget.spreadOffset(
            index: i, admitted: 3, spreadDegrees: spread,
          ), 0);
        }
      }
    });
  });
}
