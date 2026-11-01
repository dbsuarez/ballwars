import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = SkillDefinition(
    id: 'custom.artwork-test',
    name: 'Artwork test',
    baseKind: PowerUpKind.pistol,
    custom: true,
    iconSpriteId: 'icon.png',
  );

  test('held visibility defaults preserve ordinary guns and boomerangs', () {
    expect(original.hidesHeldDuringFlight, isFalse);
    final boomerang = SkillDefinition.fromJson({...original.toJson(), 'base': PowerUpKind.boomerang.name})!;
    expect(boomerang.hidesHeldDuringFlight, isTrue);
    expect(boomerang.copyWith(hideHeldWhileThrown: false).hidesHeldDuringFlight, isFalse);
    expect(original.copyWith(hideHeldWhileThrown: true).hidesHeldDuringFlight, isTrue);
    expect(SkillDefinition.fromJson(original.copyWith(
      hideHeldWhileThrown: true,
    ).toJson())!.hidesHeldDuringFlight, isTrue);
  });

  test('boomerang held visibility setting round-trips and can be reset', () {
    final boomerang = SkillDefinition.fromJson({
      ...original.toJson(),
      'base': PowerUpKind.boomerang.name,
      'hide_held_while_thrown': false,
    })!;
    expect(SkillDefinition.fromJson(boomerang.toJson())!.hideHeldWhileThrown, false);
    expect(boomerang.copyWith(hideHeldWhileThrown: true).hideHeldWhileThrown, true);
    expect(boomerang.copyWith(hideHeldWhileThrown: null).hideHeldWhileThrown, isNull);
    expect(original.hideHeldWhileThrown, isNull);
  });

  test('pickup and held default independently to icon', () {
    expect(original.effectivePickupSpriteId, 'icon.png');
    expect(original.effectiveHeldSpriteId, 'icon.png');
  });

  test('independent slots persist and survive copyWith', () {
    final edited = original.copyWith(
      pickupSpriteId: 'pickup.png',
      heldSpriteId: 'held.png',
    );
    expect(edited.effectivePickupSpriteId, 'pickup.png');
    expect(edited.effectiveHeldSpriteId, 'held.png');
    final restored = SkillDefinition.fromJson(edited.toJson())!;
    expect(restored.pickupSpriteId, 'pickup.png');
    expect(restored.heldSpriteId, 'held.png');
    expect(restored.iconSpriteId, 'icon.png');
    final cleared = restored.copyWith(heldSpriteId: null);
    expect(cleared.effectiveHeldSpriteId, 'icon.png');
    expect(cleared.effectivePickupSpriteId, 'pickup.png');
  });

  test('legacy casting and impact artwork migrate into visual events', () {
    final legacy = original.copyWith(
      castingSpriteId: 'cast.png',
      impactSpriteId: 'hit.png',
    );
    final result = SkillLibrary.defaults.migrateLegacyArtwork(legacy);
    expect(result.skill.castingSpriteId, isNull);
    expect(result.skill.impactSpriteId, isNull);
    expect(result.library.resolveVisual(result.skill, SkillVisualRole.casting)?.spriteId, 'cast.png');
    expect(result.library.resolveVisual(result.skill, SkillVisualRole.impact)?.spriteId, 'hit.png');
    final second = result.library.migrateLegacyArtwork(result.skill);
    expect(second.library.effects.length, 2);
    expect(second.skill.visualBindings.length, 3);
  });

  test('retrying migration with stale skill does not duplicate effects', () {
    final stale = original.copyWith(castingSpriteId: 'cast.png');
    final first = SkillLibrary.defaults.migrateLegacyArtwork(stale);
    final retried = first.library.migrateLegacyArtwork(stale);
    expect(retried.library.effects.length, first.library.effects.length);
    expect(retried.skill.visualBindings[SkillVisualRole.casting]?.effectId,
        first.skill.visualBindings[SkillVisualRole.casting]?.effectId);
  });

  test('different legacy artwork gets its own effect without replacing old', () {
    final first = SkillLibrary.defaults.migrateLegacyArtwork(
      original.copyWith(castingSpriteId: 'cast-a.png'),
    );
    final second = first.library.migrateLegacyArtwork(
      original.copyWith(castingSpriteId: 'cast-b.png'),
    );
    expect(second.library.effects.length, 2);
    expect(first.library.resolveVisual(first.skill, SkillVisualRole.casting)?.spriteId,
        'cast-a.png');
    expect(second.library.resolveVisual(second.skill, SkillVisualRole.casting)?.spriteId,
        'cast-b.png');
  });

  test('existing visual event bindings are not overwritten by migration', () {
    final library = SkillLibrary.defaults.withEffect(
      const EffectDefinition(id: 'existing', name: 'Existing', spriteId: 'new.png'),
    );
    final skill = original.copyWith(
      castingSpriteId: 'old.png',
      visualBindings: {SkillVisualRole.casting: const SkillVisualBinding(effectId: 'existing')},
    );
    final result = library.migrateLegacyArtwork(skill);
    expect(result.library.effects.length, 1);
    expect(result.library.resolveVisual(result.skill, SkillVisualRole.casting)?.spriteId, 'new.png');
    expect(result.skill.castingSpriteId, isNull);
  });

  test('migration keeps existing binding and converts only unbound role', () {
    final library = SkillLibrary.defaults.withEffect(
      const EffectDefinition(id: 'user.effect', name: 'User effect', spriteId: 'chosen.png'),
    );
    final skill = original.copyWith(
      castingSpriteId: 'old-cast.png',
      impactSpriteId: 'old-hit.png',
      visualBindings: {
        SkillVisualRole.casting: const SkillVisualBinding(effectId: 'user.effect'),
      },
    );
    final result = library.migrateLegacyArtwork(skill);
    expect(result.skill.castingSpriteId, isNull);
    expect(result.skill.impactSpriteId, isNull);
    expect(result.library.resolveVisual(result.skill, SkillVisualRole.casting)?.spriteId, 'chosen.png');
    expect(result.library.resolveVisual(result.skill, SkillVisualRole.impact)?.spriteId, 'old-hit.png');
    expect(result.library.effects.length, 2);
  });

  test('legacy JSON retains icon fallback', () {
    final restored = SkillDefinition.fromJson(original.toJson())!;
    expect(restored.pickupSpriteId, isNull);
    expect(restored.heldSpriteId, isNull);
    expect(restored.effectivePickupSpriteId, 'icon.png');
    expect(restored.effectiveHeldSpriteId, 'icon.png');
  });
}
