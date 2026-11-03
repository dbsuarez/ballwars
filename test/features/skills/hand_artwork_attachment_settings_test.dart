import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = SkillDefinition(
    id: 'custom.hand-art',
    name: 'Hand artwork',
    baseKind: PowerUpKind.pistol,
    custom: true,
  );

  test('legacy skills retain their previous attachment defaults', () {
    final old = base.toJson()
      ..remove('held_attachment')
      ..remove('effect_attachment')
      ..remove('held_offset_x')
      ..remove('held_offset_y')
      ..remove('effect_offset_x')
      ..remove('effect_offset_y');
    final restored = SkillDefinition.fromJson(old)!;
    expect(restored.heldAttachment, 'right');
    expect(restored.effectAttachment, 'both');
    expect(restored.heldOffsetX, 0);
    expect(restored.effectOffsetY, 0);
  });

  test('default placement fields stay absent from legacy snapshots', () {
    final json = base.toJson();
    for (final key in [
      'held_attachment',
      'effect_attachment',
      'held_offset_x',
      'held_offset_y',
      'effect_offset_x',
      'effect_offset_y',
    ]) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
    final nonDefault = base.copyWith(
      heldAttachment: 'left',
      effectAttachment: 'right',
      heldOffsetX: 0.25,
      effectOffsetY: -0.5,
    ).toJson();
    expect(nonDefault['held_attachment'], 'left');
    expect(nonDefault['effect_attachment'], 'right');
    expect(nonDefault['held_offset_x'], 0.25);
    expect(nonDefault['effect_offset_y'], -0.5);
    expect(nonDefault.containsKey('held_offset_y'), isFalse);
    expect(nonDefault.containsKey('effect_offset_x'), isFalse);
  });

  test('sprite and effect placement save and reload independently', () {
    final updated = base.copyWith(
      heldAttachment: 'left',
      effectAttachment: 'both',
      heldOffsetX: -0.25,
      heldOffsetY: 0.5,
      effectOffsetX: 0.75,
      effectOffsetY: -0.4,
    );
    final restored = SkillDefinition.fromJson(
      jsonDecode(jsonEncode(updated.toJson())),
    )!;
    expect(restored.heldAttachment, 'left');
    expect(restored.effectAttachment, 'both');
    expect(restored.heldOffsetX, -0.25);
    expect(restored.heldOffsetY, 0.5);
    expect(restored.effectOffsetX, 0.75);
    expect(restored.effectOffsetY, -0.4);
    expect(restored.copyWith(effectAttachment: 'right').heldAttachment, 'left');
  });

  test('invalid attachment and excessive offsets normalize safely', () {
    final restored = base.copyWith(
      heldAttachment: 'invalid',
      effectAttachment: 'invalid',
      heldOffsetX: -100,
      effectOffsetY: 100,
    ).validated();
    expect(restored.heldAttachment, 'right');
    expect(restored.effectAttachment, 'both');
    expect(restored.heldOffsetX, -2);
    expect(restored.effectOffsetY, 2);
  });
}
