import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/native_advanced_skill_config.dart';

void main() {
  test('native clone defaults preserve tuning', () {
    expect(NativeAdvancedSkillConfig.cloneCount(null, 4), 4);
  });
  test('native clone overrides are bounded', () {
    expect(NativeAdvancedSkillConfig.cloneCount(6, 4), 6);
    expect(NativeAdvancedSkillConfig.cloneCount(0, 4), 1);
    expect(NativeAdvancedSkillConfig.cloneCount(999, 4), 100);
  });
  test('native selection preserves arena order and skips owner', () {
    final owner = Object();
    final a = Object();
    final b = Object();
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: [owner, a, b],
      isActive: (_) => true, limit: -1,
    ), [a, b]);
  });
  test('native selection respects target limit', () {
    final owner = Object();
    final targets = [Object(), Object(), Object()];
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: targets,
      isActive: (_) => true, limit: 2,
    ), targets.take(2).toList());
  });
  test('native selection ignores inactive and repeated players', () {
    final owner = Object();
    final inactive = Object();
    final active = Object();
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: owner, candidates: [inactive, active, active, inactive],
      isActive: (value) => !identical(value, inactive), limit: -1,
    ), [active]);
  });
  test('native selection with zero limit is empty', () {
    expect(NativeAdvancedTargetSelection.select<Object>(
      owner: Object(), candidates: [Object()],
      isActive: (_) => true, limit: 0,
    ), isEmpty);
  });
  test('omega defaults to every target', () {
    expect(NativeAdvancedSkillConfig.targetLimit(null), -1);
  });
  test('omega configured target count is bounded', () {
    expect(NativeAdvancedSkillConfig.targetLimit(3), 3);
    expect(NativeAdvancedSkillConfig.targetLimit(0), 1);
    expect(NativeAdvancedSkillConfig.targetLimit(999), 100);
  });
}
