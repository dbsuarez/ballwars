import 'package:ballwars/features/skills/domain/skill_projectile_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single remaining slot fires on aim axis', () {
    expect(SkillProjectileBudget.spreadOffset(
      index: 0, admitted: 1, spreadDegrees: 45), 0);
  });
  test('partial volley distributes symmetrically over admitted shots', () {
    final offsets = [for (var i = 0; i < 3; i++)
      SkillProjectileBudget.spreadOffset(
        index: i, admitted: 3, spreadDegrees: 40)];
    expect(offsets, [-20, 0, 20]);
  });
  test('invalid spread or index cannot produce NaN angles', () {
    expect(SkillProjectileBudget.spreadOffset(
      index: 1, admitted: 1, spreadDegrees: double.nan), 0);
    expect(SkillProjectileBudget.spreadOffset(
      index: -1, admitted: 3, spreadDegrees: 40), 0);
  });

  test('full queue rejects entire volley without evicting shots', () {
    expect(SkillProjectileBudget.admitted(active: 96, requested: 3, limit: 96), 0);
  });
  test('partial capacity admits only available projectiles', () {
    expect(SkillProjectileBudget.admitted(active: 94, requested: 3, limit: 96), 2);
  });
  test('empty queue admits requested volley', () {
    expect(SkillProjectileBudget.admitted(active: 0, requested: 3, limit: 96), 3);
  });
  test('nonpositive requests and invalid limits reject safely', () {
    expect(SkillProjectileBudget.admitted(active: 0, requested: 0, limit: 96), 0);
    expect(SkillProjectileBudget.admitted(active: 0, requested: 3, limit: 0), 0);
  });
  test('negative active count cannot increase capacity', () {
    expect(SkillProjectileBudget.admitted(active: -2, requested: 200, limit: 96), 96);
  });
}
