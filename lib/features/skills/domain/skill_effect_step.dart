part of 'skill_library.dart';

enum EffectStepTarget {
  affected('Hit targets'),
  self('Caster'),
  nearestOpponent('Nearest opponent'),
  allOpponents('All opponents');

  const EffectStepTarget(this.label);
  final String label;
}

/// A finite, ordered mechanical operation. No recursive skill references or loops.
/// Null parameters inherit the skill's values; artwork never supplies mechanics.
class SkillEffectStep {
  const SkillEffectStep({
    required this.type,
    this.target = EffectStepTarget.affected,
    this.delaySeconds = 0,
    this.damage,
    this.threadDamage,
    this.healing,
    this.durationSeconds,
    this.tickIntervalSeconds,
    this.knockback,
    this.strength,
    this.shieldHits,
    this.targetRangeRatio,
    this.frozenDamageMultiplier,
    this.frozenCollisionDamage,
  });

  final SkillEffectType type;
  final EffectStepTarget target;

  /// Wait after the previous step starts. Equal times execute in list order.
  final double delaySeconds;
  final double? damage, healing, durationSeconds, tickIntervalSeconds;
  final double? knockback, strength, targetRangeRatio;
  final double? frozenDamageMultiplier, frozenCollisionDamage;
  final int? threadDamage, shieldHits;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'target': target.name,
    if (delaySeconds != 0) 'delay': delaySeconds,
    if (damage != null) 'damage': damage,
    if (threadDamage != null) 'threads': threadDamage,
    if (healing != null) 'healing': healing,
    if (durationSeconds != null) 'duration': durationSeconds,
    if (tickIntervalSeconds != null) 'tick': tickIntervalSeconds,
    if (knockback != null) 'knockback': knockback,
    if (strength != null) 'strength': strength,
    if (shieldHits != null) 'shield_hits': shieldHits,
    if (targetRangeRatio != null) 'target_range': targetRangeRatio,
    if (frozenDamageMultiplier != null)
      'frozen_multiplier': frozenDamageMultiplier,
    if (frozenCollisionDamage != null)
      'frozen_collision': frozenCollisionDamage,
  };

  factory SkillEffectStep.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Effect step must be an object.');
    }
    const allowed = {
      'type',
      'target',
      'delay',
      'damage',
      'threads',
      'healing',
      'duration',
      'tick',
      'knockback',
      'strength',
      'shield_hits',
      'target_range',
      'frozen_multiplier',
      'frozen_collision',
    };
    if (value.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException(
        'Unsupported effect step fields. Loops and skill references are not allowed.',
      );
    }
    final type = SkillEffectType.values
        .where((e) => e.name == value['type'])
        .firstOrNull;
    final target = EffectStepTarget.values
        .where((e) => e.name == value['target'])
        .firstOrNull;
    if (type == null || (value['target'] != null && target == null)) {
      throw const FormatException('Unknown effect step or target.');
    }
    double? number(String key, double min, double max) {
      final v = value[key];
      if (v == null) return null;
      if (v is! num || !v.isFinite || v < min || v > max) {
        throw FormatException('Effect step $key must be $min to $max.');
      }
      return v.toDouble();
    }

    int? integer(String key, int max) {
      final v = number(key, 0, max.toDouble());
      if (v != null && v != v.roundToDouble()) {
        throw FormatException('Effect step $key must be a whole number.');
      }
      return v?.toInt();
    }

    return SkillEffectStep(
      type: type,
      target: target ?? EffectStepTarget.affected,
      delaySeconds: number('delay', 0, 10) ?? 0,
      damage: number('damage', 0, 500),
      threadDamage: integer('threads', 360),
      healing: number('healing', 0, 500),
      durationSeconds: number('duration', .1, 60),
      tickIntervalSeconds: number('tick', .1, 10),
      knockback: number('knockback', 0, 100),
      strength: number('strength', 0, 10),
      shieldHits: integer('shield_hits', 20),
      targetRangeRatio: number('target_range', .05, 1),
      frozenDamageMultiplier: number('frozen_multiplier', 1, 5),
      frozenCollisionDamage: number('frozen_collision', 0, 200),
    );
  }

  static List<SkillEffectStep> parseList(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List || raw.length > SkillDefinition.maxEffectSteps) {
      throw const FormatException('Use at most 8 mechanical effect steps.');
    }
    return List.unmodifiable(raw.map(SkillEffectStep.fromJson));
  }

  static List<SkillEffectStep> validateList(List<SkillEffectStep> steps) =>
      parseList(steps.map((s) => s.toJson()).toList());

  SkillDefinition applyTo(SkillDefinition skill) => skill.copyWith(
    effectSteps: const [],
    effectType: type,
    secondaryEffectType: null,
    arsenalDamage: damage,
    allOutDamage: threadDamage,
    dotArsenalDamage: damage,
    dotAllOutDamage: threadDamage,
    healing: healing,
    durationSeconds: durationSeconds,
    tickIntervalSeconds: tickIntervalSeconds,
    knockback: knockback,
    effectStrength: strength,
    shieldHits: shieldHits,
    frozenDamageMultiplier: frozenDamageMultiplier,
    frozenCollisionDamage: frozenCollisionDamage,
  );
}
