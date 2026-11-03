
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';

import 'casting_artwork_test.dart' show setup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Impact and Explosion use independent event durations per instance', () {
    final controller = setup(PowerUpKind.pistol);
    final p = controller.powerUps!;
    final hit = WeaponImpact(
      position: Offset.zero,
      strength: 1,
      kind: PowerUpKind.pistol,
      skillId: 'builtin.pistol',
    );
    final blast = Explosion(
      position: Offset.zero,
      radius: 12,
      kind: PowerUpKind.pistol,
      skillId: 'builtin.pistol',
    );
    final hitSteps = p.impactVisualSteps(hit);
    final blastSteps = p.explosionVisualSteps(blast);
    expect(hitSteps, greaterThan(0));
    expect(blastSteps, greaterThan(0));
    expect(p.impactVisualSteps(hit), hitSteps);
    expect(p.explosionVisualSteps(blast), blastSteps);
    // Each newly spawned event resolves independently; caching one role must
    // not overwrite the other role or a different instance.
    expect(p.impactVisualSteps(WeaponImpact(
      position: const Offset(2, 0), strength: 1,
      kind: PowerUpKind.pistol, skillId: 'builtin.pistol',
    )), hitSteps);
    expect(p.explosionVisualSteps(Explosion(
      position: const Offset(2, 0), radius: 12,
      kind: PowerUpKind.pistol, skillId: 'builtin.pistol',
    )), blastSteps);
  });

  test('legacy unbound Impact and Explosion retain native fallback durations', () {
    final controller = setup(PowerUpKind.pistol);
    final p = controller.powerUps!;
    final hit = WeaponImpact(position: Offset.zero, strength: 1);
    final blast = Explosion(position: Offset.zero, radius: 12);
    expect(p.impactVisualSteps(hit), 12);
    expect(p.explosionVisualSteps(blast), PowerUpTuning.explosionShowSteps);
  });

  test('Impact lifetime is stable after advancing the effect age', () {
    final p = setup(PowerUpKind.pistol).powerUps!;
    final hit = WeaponImpact(
      position: Offset.zero, strength: 1,
      kind: PowerUpKind.pistol, skillId: 'builtin.pistol',
    );
    final lifetime = p.impactVisualSteps(hit);
    hit.age = lifetime - 1;
    expect(p.impactVisualSteps(hit), lifetime);
    hit.age = lifetime;
    expect(p.impactVisualSteps(hit), lifetime);
  });

  test('Explosion lifetime is stable after advancing the effect age', () {
    final p = setup(PowerUpKind.pistol).powerUps!;
    final blast = Explosion(
      position: Offset.zero, radius: 12,
      kind: PowerUpKind.pistol, skillId: 'builtin.pistol',
    );
    final lifetime = p.explosionVisualSteps(blast);
    blast.age = lifetime - 1;
    expect(p.explosionVisualSteps(blast), lifetime);
    blast.age = lifetime;
    expect(p.explosionVisualSteps(blast), lifetime);
  });

}
