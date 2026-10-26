import 'dart:convert';

import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';

enum SkillVisualMode { sprite, vector }

enum SkillTrigger {
  pickup,
  aimedFire,
  collision,
  timer,
  damageTaken,
  elimination,
}

enum SkillTargeting {
  self,
  nearestOpponent,
  allOpponents,
  chosenDirection,
  arenaLocation,
}

enum SkillDelivery {
  instant,
  projectile,
  area,
  beam,
  aura,
  orbit,
  boundaryHazard,
}

enum SkillEffectType {
  damage,
  damageOverTime,
  heal,
  shield,
  freeze,
  stun,
  speed,
  pull,
  knockback,
  teleport,
  equipCarrier,
  disarm,
}

enum SkillCalloutStyle { normal, rare, epic, special }

enum SkillBubbleType { shout, speech, thought, radio }

enum SkillHandedness { carrierDefault, oneHanded, twoHanded }

class SkillDefinition {
  static const List<String> soundCues = [
    'shot',
    'shotgun',
    'gatling',
    'slash',
    'shield',
    'bomb',
    'pickup',
    'hit',
  ];

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.baseKind,
    this.enabled = true,
    this.custom = false,
    this.arsenalDamage,
    this.allOutDamage,
    this.dotArsenalDamage,
    this.dotAllOutDamage,
    this.durationSeconds,
    this.projectileCount,
    this.projectileSpeed,
    this.spreadDegrees,
    this.maxBounces,
    this.range = 0.55,
    this.projectileSize = 1,
    this.projectileSpin = 0,
    this.homing = false,
    this.returnsToOrigin = false,
    this.trackNearestOpponent = false,
    this.weaponDisplayScale = 1,
    this.effectStrength = 1,
    this.healing = 10,
    this.shieldHits = 1,
    this.frozenDamageMultiplier = 1.5,
    this.frozenCollisionDamage = 5,
    this.knockback = 0,
    this.spriteMode = SkillVisualMode.sprite,
    this.effectMode = SkillVisualMode.sprite,
    this.soundCue = 'default',
    this.trigger,
    this.targeting,
    this.delivery,
    this.effectType,
    this.secondaryEffectType,
    this.repeatCount = 1,
    this.repeatIntervalSeconds = 0.5,
    this.startDelaySeconds = 0,
    this.tickIntervalSeconds = 0.5,
    this.cooldownSeconds = 0,
    this.triggerIntervalSeconds = 5,
    this.effectColor = 0xFFFF6B6B,
    this.screenShake = 0,
    this.handedness = SkillHandedness.carrierDefault,
    this.yell = '',
    this.calloutStyle = SkillCalloutStyle.normal,
    this.bubbleType = SkillBubbleType.shout,
  });

  final String id;
  final String name;
  final PowerUpKind baseKind;
  final bool enabled;
  final bool custom;
  final double? arsenalDamage;
  final int? allOutDamage;
  final double? dotArsenalDamage;
  final int? dotAllOutDamage;
  final double? durationSeconds;
  final int? projectileCount;
  final double? projectileSpeed;
  final double? spreadDegrees;
  final int? maxBounces;
  final double range;
  final double projectileSize;
  final double projectileSpin;
  final bool homing;
  final bool returnsToOrigin;
  final bool trackNearestOpponent;
  final double weaponDisplayScale;
  final double effectStrength;
  final double healing;
  final int shieldHits;
  final double frozenDamageMultiplier;
  final double frozenCollisionDamage;
  final double knockback;
  final SkillVisualMode spriteMode;
  final SkillVisualMode effectMode;
  final String soundCue;
  final SkillTrigger? trigger;
  final SkillTargeting? targeting;
  final SkillDelivery? delivery;
  final SkillEffectType? effectType;
  final SkillEffectType? secondaryEffectType;
  final int repeatCount;
  final double repeatIntervalSeconds;
  final double startDelaySeconds;
  final double tickIntervalSeconds;
  final double cooldownSeconds;
  final double triggerIntervalSeconds;
  final int effectColor;
  final double screenShake;
  final SkillHandedness handedness;
  final String yell;
  final SkillCalloutStyle calloutStyle;
  final SkillBubbleType bubbleType;
  bool get isComposed =>
      trigger != null &&
      targeting != null &&
      delivery != null &&
      effectType != null;

  int get estimatedMayhemLoad {
    if (!isComposed) return 0;
    final targets = targeting == SkillTargeting.allOpponents ? 7 : 1;
    final activations = repeatCount.clamp(1, 10);
    final projectiles = delivery == SkillDelivery.projectile
        ? (projectileCount ?? 1).clamp(1, 100)
        : 1;
    final ticks = effectType == SkillEffectType.damageOverTime
        ? (((durationSeconds ?? 2) / tickIntervalSeconds).ceil()).clamp(1, 600)
        : 1;
    return targets * activations * projectiles * ticks;
  }

  List<String> get performanceIssues {
    if (!isComposed) return const [];
    final issues = <String>[];
    if (estimatedMayhemLoad > 120) {
      issues.add(
        'Estimated Mayhem load is $estimatedMayhemLoad effects per activation; runtime will cap concurrent custom effects.',
      );
    }
    if (targeting == SkillTargeting.allOpponents && repeatCount > 5) {
      issues.add('Mayhem caps all-opponent repeat chains at 5 activations.');
    }
    return List.unmodifiable(issues);
  }

  SkillDefinition copyWith({
    String? id,
    String? name,
    bool? enabled,
    bool? custom,
    double? arsenalDamage,
    int? allOutDamage,
    double? dotArsenalDamage,
    int? dotAllOutDamage,
    double? durationSeconds,
    int? projectileCount,
    double? projectileSpeed,
    double? spreadDegrees,
    int? maxBounces,
    double? range,
    double? projectileSize,
    double? projectileSpin,
    bool? homing,
    bool? returnsToOrigin,
    bool? trackNearestOpponent,
    double? weaponDisplayScale,
    double? effectStrength,
    double? healing,
    int? shieldHits,
    double? frozenDamageMultiplier,
    double? frozenCollisionDamage,
    double? knockback,
    SkillVisualMode? spriteMode,
    SkillVisualMode? effectMode,
    String? soundCue,
    SkillTrigger? trigger,
    SkillTargeting? targeting,
    SkillDelivery? delivery,
    SkillEffectType? effectType,
    Object? secondaryEffectType = _unset,
    int? repeatCount,
    double? repeatIntervalSeconds,
    double? startDelaySeconds,
    double? tickIntervalSeconds,
    double? cooldownSeconds,
    double? triggerIntervalSeconds,
    int? effectColor,
    double? screenShake,
    SkillHandedness? handedness,
    String? yell,
    SkillCalloutStyle? calloutStyle,
    SkillBubbleType? bubbleType,
  }) => SkillDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    baseKind: baseKind,
    enabled: enabled ?? this.enabled,
    custom: custom ?? this.custom,
    arsenalDamage: arsenalDamage ?? this.arsenalDamage,
    allOutDamage: allOutDamage ?? this.allOutDamage,
    dotArsenalDamage: dotArsenalDamage ?? this.dotArsenalDamage,
    dotAllOutDamage: dotAllOutDamage ?? this.dotAllOutDamage,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    projectileCount: projectileCount ?? this.projectileCount,
    projectileSpeed: projectileSpeed ?? this.projectileSpeed,
    spreadDegrees: spreadDegrees ?? this.spreadDegrees,
    maxBounces: maxBounces ?? this.maxBounces,
    range: range ?? this.range,
    projectileSize: projectileSize ?? this.projectileSize,
    projectileSpin: projectileSpin ?? this.projectileSpin,
    homing: homing ?? this.homing,
    returnsToOrigin: returnsToOrigin ?? this.returnsToOrigin,
    trackNearestOpponent: trackNearestOpponent ?? this.trackNearestOpponent,
    weaponDisplayScale: weaponDisplayScale ?? this.weaponDisplayScale,
    effectStrength: effectStrength ?? this.effectStrength,
    healing: healing ?? this.healing,
    shieldHits: shieldHits ?? this.shieldHits,
    frozenDamageMultiplier:
        frozenDamageMultiplier ?? this.frozenDamageMultiplier,
    frozenCollisionDamage: frozenCollisionDamage ?? this.frozenCollisionDamage,
    knockback: knockback ?? this.knockback,
    spriteMode: spriteMode ?? this.spriteMode,
    effectMode: effectMode ?? this.effectMode,
    soundCue: soundCue ?? this.soundCue,
    trigger: trigger ?? this.trigger,
    targeting: targeting ?? this.targeting,
    delivery: delivery ?? this.delivery,
    effectType: effectType ?? this.effectType,
    secondaryEffectType: identical(secondaryEffectType, _unset)
        ? this.secondaryEffectType
        : secondaryEffectType as SkillEffectType?,
    repeatCount: repeatCount ?? this.repeatCount,
    repeatIntervalSeconds: repeatIntervalSeconds ?? this.repeatIntervalSeconds,
    startDelaySeconds: startDelaySeconds ?? this.startDelaySeconds,
    tickIntervalSeconds: tickIntervalSeconds ?? this.tickIntervalSeconds,
    cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    triggerIntervalSeconds:
        triggerIntervalSeconds ?? this.triggerIntervalSeconds,
    effectColor: effectColor ?? this.effectColor,
    screenShake: screenShake ?? this.screenShake,
    handedness: handedness ?? this.handedness,
    yell: yell ?? this.yell,
    calloutStyle: calloutStyle ?? this.calloutStyle,
    bubbleType: bubbleType ?? this.bubbleType,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'base': baseKind.name,
    'enabled': enabled,
    'custom': custom,
    if (arsenalDamage != null) 'arsenal_damage': arsenalDamage,
    if (allOutDamage != null) 'all_out_damage': allOutDamage,
    if (dotArsenalDamage != null) 'dot_arsenal_damage': dotArsenalDamage,
    if (dotAllOutDamage != null) 'dot_all_out_damage': dotAllOutDamage,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    if (projectileCount != null) 'projectile_count': projectileCount,
    if (projectileSpeed != null) 'projectile_speed': projectileSpeed,
    if (spreadDegrees != null) 'spread_degrees': spreadDegrees,
    if (maxBounces != null) 'max_bounces': maxBounces,
    'range': range,
    'projectile_size': projectileSize,
    'projectile_spin': projectileSpin,
    'homing': homing,
    'returns_to_origin': returnsToOrigin,
    'track_nearest_opponent': trackNearestOpponent,
    'weapon_display_scale': weaponDisplayScale,
    'effect_strength': effectStrength,
    'healing': healing,
    'shield_hits': shieldHits,
    'frozen_damage_multiplier': frozenDamageMultiplier,
    'frozen_collision_damage': frozenCollisionDamage,
    'knockback': knockback,
    'sprite_mode': spriteMode.name,
    'effect_mode': effectMode.name,
    'sound_cue': soundCue,
    if (trigger != null) 'trigger': trigger!.name,
    if (targeting != null) 'targeting': targeting!.name,
    if (delivery != null) 'delivery': delivery!.name,
    if (effectType != null) 'effect_type': effectType!.name,
    if (secondaryEffectType != null)
      'secondary_effect_type': secondaryEffectType!.name,
    'repeat_count': repeatCount,
    'repeat_interval_seconds': repeatIntervalSeconds,
    'start_delay_seconds': startDelaySeconds,
    'tick_interval_seconds': tickIntervalSeconds,
    'cooldown_seconds': cooldownSeconds,
    'trigger_interval_seconds': triggerIntervalSeconds,
    'effect_color': effectColor,
    'screen_shake': screenShake,
    'handedness': handedness.name,
    if (yell.isNotEmpty) 'yell': yell,
    'callout_style': calloutStyle.name,
    'bubble_type': bubbleType.name,
  };

  static SkillDefinition? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final name = value['name'];
    final base = value['base'];
    if (id is! String || name is! String || base is! String) return null;
    final kinds = PowerUpKind.values.where((kind) => kind.name == base);
    if (kinds.isEmpty || id.isEmpty || name.trim().isEmpty) return null;
    T enumValue<T extends Enum>(String key, List<T> values, T fallback) {
      final raw = value[key];
      return values.where((item) => item.name == raw).firstOrNull ?? fallback;
    }

    T? nullableEnum<T extends Enum>(String key, List<T> values) {
      final raw = value[key];
      return values.where((item) => item.name == raw).firstOrNull;
    }

    double? decimal(String key) => (value[key] as num?)?.toDouble();
    int? integer(String key) => (value[key] as num?)?.toInt();
    return SkillDefinition(
      id: id,
      name: name.trim(),
      baseKind: kinds.first,
      enabled: value['enabled'] as bool? ?? true,
      custom: value['custom'] as bool? ?? id.startsWith('custom.'),
      arsenalDamage: decimal('arsenal_damage'),
      allOutDamage: integer('all_out_damage'),
      dotArsenalDamage: decimal('dot_arsenal_damage'),
      dotAllOutDamage: integer('dot_all_out_damage'),
      durationSeconds: decimal('duration_seconds'),
      projectileCount: integer('projectile_count'),
      projectileSpeed: decimal('projectile_speed'),
      spreadDegrees: decimal('spread_degrees'),
      maxBounces: integer('max_bounces'),
      range: decimal('range') ?? 0.55,
      projectileSize: decimal('projectile_size') ?? 1,
      projectileSpin: decimal('projectile_spin') ?? 0,
      homing: value['homing'] as bool? ?? false,
      returnsToOrigin: value['returns_to_origin'] as bool? ?? false,
      trackNearestOpponent: value['track_nearest_opponent'] as bool? ?? false,
      weaponDisplayScale: decimal('weapon_display_scale') ?? 1,
      effectStrength: decimal('effect_strength') ?? 1,
      healing: decimal('healing') ?? 10,
      shieldHits: integer('shield_hits') ?? 1,
      frozenDamageMultiplier: decimal('frozen_damage_multiplier') ?? 1.5,
      frozenCollisionDamage: decimal('frozen_collision_damage') ?? 5,
      knockback: decimal('knockback') ?? 0,
      spriteMode: enumValue(
        'sprite_mode',
        SkillVisualMode.values,
        SkillVisualMode.sprite,
      ),
      effectMode: enumValue(
        'effect_mode',
        SkillVisualMode.values,
        SkillVisualMode.sprite,
      ),
      soundCue: value['sound_cue'] as String? ?? 'default',
      trigger: nullableEnum('trigger', SkillTrigger.values),
      targeting: nullableEnum('targeting', SkillTargeting.values),
      delivery: nullableEnum('delivery', SkillDelivery.values),
      effectType: nullableEnum('effect_type', SkillEffectType.values),
      secondaryEffectType: nullableEnum(
        'secondary_effect_type',
        SkillEffectType.values,
      ),
      repeatCount: integer('repeat_count') ?? 1,
      repeatIntervalSeconds: decimal('repeat_interval_seconds') ?? 0.5,
      startDelaySeconds: decimal('start_delay_seconds') ?? 0,
      tickIntervalSeconds: decimal('tick_interval_seconds') ?? 0.5,
      cooldownSeconds: decimal('cooldown_seconds') ?? 0,
      triggerIntervalSeconds: decimal('trigger_interval_seconds') ?? 5,
      effectColor: integer('effect_color') ?? 0xFFFF6B6B,
      screenShake: decimal('screen_shake') ?? 0,
      handedness: enumValue(
        'handedness',
        SkillHandedness.values,
        SkillHandedness.carrierDefault,
      ),
      yell: value['yell'] as String? ?? '',
      calloutStyle: enumValue(
        'callout_style',
        SkillCalloutStyle.values,
        SkillCalloutStyle.normal,
      ),
      bubbleType: enumValue(
        'bubble_type',
        SkillBubbleType.values,
        SkillBubbleType.shout,
      ),
    ).validated();
  }

  SkillDefinition validated() => copyWith(
    name: name.trim().substring(0, name.trim().length.clamp(1, 40)),
    arsenalDamage: arsenalDamage?.clamp(0, 500),
    allOutDamage: allOutDamage?.clamp(0, 360),
    dotArsenalDamage: dotArsenalDamage?.clamp(0, 500),
    dotAllOutDamage: dotAllOutDamage?.clamp(0, 360),
    durationSeconds: durationSeconds?.clamp(0.1, 60),
    projectileCount: projectileCount?.clamp(1, 100),
    projectileSpeed: projectileSpeed?.clamp(0.1, 10),
    spreadDegrees: spreadDegrees?.clamp(0, 360),
    maxBounces: maxBounces?.clamp(0, 20),
    range: range.clamp(0.05, 12),
    projectileSize: projectileSize.clamp(0.1, 5),
    projectileSpin: projectileSpin.clamp(-2160, 2160),
    weaponDisplayScale: weaponDisplayScale.clamp(0.25, 3),
    effectStrength: effectStrength.clamp(0, 10),
    healing: healing.clamp(0, 500),
    shieldHits: shieldHits.clamp(0, 20),
    frozenDamageMultiplier: frozenDamageMultiplier.clamp(1, 5),
    frozenCollisionDamage: frozenCollisionDamage.clamp(0, 200),
    knockback: knockback.clamp(0, 10),
    repeatCount: repeatCount.clamp(1, 10),
    repeatIntervalSeconds: repeatIntervalSeconds.clamp(0.1, 10),
    startDelaySeconds: startDelaySeconds.clamp(0, 30),
    tickIntervalSeconds: tickIntervalSeconds.clamp(0.1, 10),
    cooldownSeconds: cooldownSeconds.clamp(0, 60),
    triggerIntervalSeconds: triggerIntervalSeconds.clamp(0.5, 120),
    effectColor: effectColor.clamp(0, 0xFFFFFFFF),
    screenShake: screenShake.clamp(0, 1),
    soundCue: soundCues.contains(soundCue) ? soundCue : 'shot',
    yell: yell.trim().substring(0, yell.trim().length.clamp(0, 60)),
  );

  List<String> get compatibilityIssues {
    if (!isComposed) return const [];
    final issues = <String>[];
    if ((trigger == SkillTrigger.aimedFire ||
            trigger == SkillTrigger.collision) &&
        !baseKind.isWeapon) {
      issues.add('Aimed fire and collision triggers require a weapon carrier.');
    }
    if ((trigger == SkillTrigger.damageTaken ||
            trigger == SkillTrigger.elimination) &&
        cooldownSeconds < 0.1) {
      issues.add('Reactive triggers require a cooldown of at least 0.1 s.');
    }
    if (delivery == SkillDelivery.projectile &&
        trigger != SkillTrigger.aimedFire) {
      issues.add('Projectile delivery requires the aimed fire trigger.');
    }
    if (delivery == SkillDelivery.projectile &&
        targeting == SkillTargeting.self) {
      issues.add('A projectile cannot target its owner.');
    }
    if (delivery == SkillDelivery.beam && targeting == SkillTargeting.self) {
      issues.add('A beam cannot target its owner.');
    }
    if (delivery == SkillDelivery.boundaryHazard &&
        targeting == SkillTargeting.self) {
      issues.add('A boundary hazard cannot target its owner.');
    }
    final effects = [effectType, secondaryEffectType];
    if (effects.contains(SkillEffectType.equipCarrier) && !baseKind.isWeapon) {
      issues.add('Equip carrier requires a weapon carrier.');
    }
    return List.unmodifiable(issues);
  }
}

const Object _unset = Object();

class SkillLibrary {
  const SkillLibrary({
    this.version = 1,
    this.overrides = const {},
    this.custom = const [],
  });

  final int version;
  final Map<String, SkillDefinition> overrides;
  final List<SkillDefinition> custom;

  static const SkillLibrary defaults = SkillLibrary();
  static const int currentVersion = 1;
  static const int maxImportCharacters = 1000000;
  static const int maxImportedDefinitions = 512;
  static const int maxReplayCharacters = 48000;

  bool get isDefault => overrides.isEmpty && custom.isEmpty;

  SkillDefinition builtIn(PowerUpKind kind, PowerUpConfig tuning) =>
      overrides['builtin.${kind.name}'] ?? _defaultFor(kind, tuning);

  /// The enabled custom variant for [kind], or its built-in definition.
  /// Only one custom variant of a base skill may be active at a time.
  SkillDefinition activeFor(PowerUpKind kind, PowerUpConfig tuning) =>
      custom
          .where((skill) => skill.enabled && skill.baseKind == kind)
          .firstOrNull ??
      builtIn(kind, tuning);

  List<SkillDefinition> all(PowerUpConfig tuning) => [
    for (final kind in PowerUpKind.values) builtIn(kind, tuning),
    ...custom,
  ];

  SkillLibrary withDefinition(
    SkillDefinition definition,
    PowerUpConfig tuning,
  ) {
    final valid = definition.validated();
    if (valid.custom) {
      final next = [
        for (final item in custom)
          if (valid.enabled &&
              item.id != valid.id &&
              item.baseKind == valid.baseKind)
            item.copyWith(enabled: false)
          else
            item,
      ];
      final index = next.indexWhere((item) => item.id == valid.id);
      if (index < 0) {
        next.add(valid);
      } else {
        next[index] = valid;
      }
      return SkillLibrary(
        version: version,
        overrides: overrides,
        custom: List.unmodifiable(next),
      );
    }
    final next = Map<String, SkillDefinition>.of(overrides);
    final original = _defaultFor(valid.baseKind, tuning);
    if (_same(valid, original)) {
      next.remove(valid.id);
    } else {
      next[valid.id] = valid;
    }
    return SkillLibrary(
      version: version,
      overrides: Map.unmodifiable(next),
      custom: custom,
    );
  }

  SkillLibrary removeCustom(String id) => SkillLibrary(
    version: version,
    overrides: overrides,
    custom: List.unmodifiable(custom.where((item) => item.id != id)),
  );

  SkillDefinition duplicate(SkillDefinition source, String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final prefix = slug.isEmpty ? source.baseKind.name : slug;
    var id = 'custom.$prefix';
    var suffix = 2;
    final used = {...overrides.keys, ...custom.map((item) => item.id)};
    while (used.contains(id)) {
      id = 'custom.$prefix-$suffix';
      suffix++;
    }
    return source.copyWith(id: id, name: name, custom: true, enabled: false);
  }

  /// Creates a behavior-composed skill that uses [carrier] only for its
  /// pickup slot, icon, and equipment rules.
  SkillDefinition create(String name, PowerUpKind carrier) {
    final seed = builtIn(carrier, PowerUpConfig.defaults);
    final draft = duplicate(seed, name);
    return draft.copyWith(
      arsenalDamage: 10,
      allOutDamage: 5,
      dotArsenalDamage: 2,
      dotAllOutDamage: 1,
      durationSeconds: 2,
      projectileCount: 1,
      projectileSpeed: 1.4,
      range: 0.55,
      projectileSize: 1,
      effectStrength: 1,
      healing: 10,
      shieldHits: 1,
      knockback: 1,
      trigger: carrier.isWeapon ? SkillTrigger.aimedFire : SkillTrigger.pickup,
      targeting: carrier.isWeapon
          ? SkillTargeting.nearestOpponent
          : SkillTargeting.self,
      delivery: carrier.isWeapon
          ? SkillDelivery.projectile
          : SkillDelivery.instant,
      effectType: SkillEffectType.damage,
      yell: name.toUpperCase(),
    );
  }

  PowerUpConfig applyTo(PowerUpConfig tuning) {
    var result = tuning;
    for (final kind in PowerUpKind.values) {
      final skill = activeFor(kind, tuning);
      final explicitlyConfigured =
          skill.custom || overrides.containsKey(skill.id);
      if (skill.arsenalDamage != null &&
          (PowerUpConfig.damageKinds.contains(kind) ||
              kind == PowerUpKind.speed)) {
        result = result.withValue('dmg.${kind.name}', skill.arsenalDamage!);
      }
      if (skill.allOutDamage != null &&
          (PowerUpConfig.damageKinds.contains(kind) ||
              kind == PowerUpKind.speed)) {
        result = result.withValue('lines.${kind.name}', skill.allOutDamage!);
      }
      if (skill.projectileCount != null) {
        if (kind == PowerUpKind.shotgun) {
          result = result.withValue('pellets', skill.projectileCount!);
        }
        if (kind == PowerUpKind.gatling) {
          result = result.withValue('rounds', skill.projectileCount!);
        }
        if (kind == PowerUpKind.bow) {
          result = result.withValue('arrows', skill.projectileCount!);
        }
      }
      if (skill.durationSeconds != null) {
        if (kind == PowerUpKind.speed) {
          result = result.withValue('speed', skill.durationSeconds!);
        }
        if (kind == PowerUpKind.freeze) {
          result = result.withValue('freeze', skill.durationSeconds!);
        }
        if (kind == PowerUpKind.ghost) {
          result = result.withValue('ghost', skill.durationSeconds!);
        }
        if (kind == PowerUpKind.overcharge) {
          result = result.withValue(
            'maximumPowerDuration',
            skill.durationSeconds!,
          );
        }
        if (kind == PowerUpKind.repulsor) {
          result = result.withValue('repulsorDuration', skill.durationSeconds!);
        }
        if (kind == PowerUpKind.timeBubble) {
          result = result.withValue(
            'timeBubbleDuration',
            skill.durationSeconds!,
          );
        }
      }
      if (explicitlyConfigured && kind == PowerUpKind.speed) {
        result = result.withValue('speedFactor', skill.effectStrength);
      }
      if (explicitlyConfigured && kind == PowerUpKind.overcharge) {
        result = result.withValue('maximumPowerAmount', skill.effectStrength);
      }
      if (explicitlyConfigured && kind == PowerUpKind.repulsor) {
        result = result.withValue('repulsorForce', skill.effectStrength);
      }
      if (explicitlyConfigured && kind == PowerUpKind.timeBubble) {
        result = result.withValue('timeBubbleRange', skill.range);
      }
      if (explicitlyConfigured && kind == PowerUpKind.freeze) {
        result = result
            .withValue('frozenDamageMultiplier', skill.frozenDamageMultiplier)
            .withValue('frozenCollisionDamage', skill.frozenCollisionDamage);
      }
      if (explicitlyConfigured && skill.projectileSpeed != null && kind.isGun) {
        result = result.withValue(
          'skillSpeed.${kind.name}',
          skill.projectileSpeed!,
        );
      }
      if (explicitlyConfigured &&
          skill.spreadDegrees != null &&
          kind == PowerUpKind.shotgun) {
        result = result.withValue(
          'skillSpread.shotgun',
          skill.spreadDegrees! * 3.141592653589793 / 180,
        );
      }
      if (explicitlyConfigured && skill.maxBounces != null) {
        result = result.withValue(
          'skillBounces.${kind.name}',
          skill.maxBounces!,
        );
      }
      if (explicitlyConfigured) {
        result = result.withValue(
          'skillKnockback.${kind.name}',
          skill.knockback,
        );
      }
    }
    return result;
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'overrides': {
      for (final entry in overrides.entries) entry.key: entry.value.toJson(),
    },
    'custom': [for (final item in custom) item.toJson()],
  };

  /// Immutable skill snapshot embedded in replay links. The replay keeps the
  /// exact definitions that were active when it was created, so later admin
  /// edits cannot change an old match.
  String? encodeReplay() {
    if (isDefault) return null;
    final source = jsonEncode(toJson());
    if (source.length > maxReplayCharacters) {
      throw const FormatException('The active skill snapshot is too large.');
    }
    return base64Url.encode(utf8.encode(source)).replaceAll('=', '');
  }

  static SkillLibrary? decodeReplay(String encoded) {
    if (encoded.isEmpty || encoded.length > maxReplayCharacters * 2) {
      return null;
    }
    try {
      final padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
      final source = utf8.decode(base64Url.decode(padded));
      if (source.length > maxReplayCharacters) return null;
      return importJson(source);
    } catch (_) {
      return null;
    }
  }

  factory SkillLibrary.fromJson(Object? value) {
    if (value is! Map) return defaults;
    final overrides = <String, SkillDefinition>{};
    final rawOverrides = value['overrides'];
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final definition = SkillDefinition.fromJson(entry.value);
        if (entry.key is String && definition != null && !definition.custom) {
          overrides[entry.key as String] = definition.yell.isEmpty
              ? definition.copyWith(yell: _defaultYellFor(definition.baseKind))
              : definition;
        }
      }
    }
    final custom = <SkillDefinition>[];
    final rawCustom = value['custom'];
    if (rawCustom is List) {
      for (final raw in rawCustom) {
        final definition = SkillDefinition.fromJson(raw);
        if (definition != null && definition.custom) {
          custom.add(
            definition.yell.isEmpty && !definition.isComposed
                ? definition.copyWith(
                    yell: _defaultYellFor(definition.baseKind),
                  )
                : definition,
          );
        }
      }
    }
    return SkillLibrary(
      version: (value['version'] as num?)?.toInt().clamp(1, 100) ?? 1,
      overrides: Map.unmodifiable(overrides),
      custom: List.unmodifiable(custom),
    );
  }

  static SkillLibrary importJson(String source) {
    if (source.trim().isEmpty) throw const FormatException('Paste JSON first.');
    if (source.length > maxImportCharacters) {
      throw const FormatException('Skill library JSON is too large.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const FormatException('This is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const FormatException('The JSON root must be an object.');
    }
    final version = decoded['version'];
    if (version is! num || version.toInt() != currentVersion) {
      throw FormatException(
        'Unsupported skill-library version. Expected $currentVersion.',
      );
    }
    final overrides = decoded['overrides'];
    final custom = decoded['custom'];
    if (overrides is! Map || custom is! List) {
      throw const FormatException('JSON must contain overrides and custom.');
    }
    if (overrides.length + custom.length > maxImportedDefinitions) {
      throw const FormatException(
        'The skill library contains too many skills.',
      );
    }
    for (final entry in overrides.entries) {
      final skill = SkillDefinition.fromJson(entry.value);
      if (entry.key is! String || skill == null || skill.custom) {
        throw const FormatException('An override definition is invalid.');
      }
    }
    for (final value in custom) {
      final skill = SkillDefinition.fromJson(value);
      if (skill == null || !skill.custom) {
        throw const FormatException('A custom skill definition is invalid.');
      }
    }
    final library = SkillLibrary.fromJson(decoded);
    final ids = <String>{};
    for (final skill in [...library.overrides.values, ...library.custom]) {
      if (!ids.add(skill.id)) {
        throw FormatException('Duplicate skill ID: ${skill.id}.');
      }
    }
    for (final kind in PowerUpKind.values) {
      if (library.custom.where((s) => s.baseKind == kind && s.enabled).length >
          1) {
        throw FormatException(
          'Only one active custom skill may use ${kind.label}.',
        );
      }
    }
    return library;
  }

  static SkillDefinition _defaultFor(PowerUpKind kind, PowerUpConfig tuning) {
    final damaging =
        PowerUpConfig.damageKinds.contains(kind) || kind == PowerUpKind.speed;
    final duration = switch (kind) {
      PowerUpKind.speed => tuning.speedSteps / 60,
      PowerUpKind.freeze => tuning.freezeSteps / 60,
      PowerUpKind.ghost => tuning.ghostSteps / 60,
      PowerUpKind.repulsor => tuning.repulsorSteps / 60,
      PowerUpKind.timeBubble => tuning.timeBubbleSteps / 60,
      PowerUpKind.overcharge => tuning.maximumPowerSteps / 60,
      PowerUpKind.vampire || PowerUpKind.magneticField => 3.0,
      _ => null,
    };
    final count = switch (kind) {
      PowerUpKind.shotgun => tuning.shotgunPellets,
      PowerUpKind.gatling => tuning.gatlingRounds,
      PowerUpKind.bow => tuning.bowArrows,
      PowerUpKind.lightningStrikes => 3,
      _ => null,
    };
    final bounces = switch (kind) {
      PowerUpKind.ricochetDisc || PowerUpKind.prismLaser => 1,
      _ => null,
    };
    return SkillDefinition(
      id: 'builtin.${kind.name}',
      name: kind.label,
      baseKind: kind,
      arsenalDamage: damaging ? tuning.arenaDamage(kind) : null,
      allOutDamage: damaging ? tuning.allOutThreads(kind) : null,
      durationSeconds: duration,
      projectileCount: count,
      projectileSpeed: kind.isGun ? tuning.bulletSpeedRatio : null,
      spreadDegrees: kind == PowerUpKind.shotgun
          ? 34
          : kind == PowerUpKind.bow
          ? 42
          : null,
      maxBounces: bounces,
      range: kind == PowerUpKind.timeBubble ? tuning.timeBubbleRange : 0.55,
      projectileSize: kind == PowerUpKind.boomerang ? 2 : 1,
      projectileSpin:
          kind == PowerUpKind.boomerang || kind == PowerUpKind.ricochetDisc
          ? 420
          : 0,
      homing: kind == PowerUpKind.rocketLauncher,
      returnsToOrigin: kind == PowerUpKind.boomerang,
      trackNearestOpponent: kind == PowerUpKind.shield,
      weaponDisplayScale: 1,
      effectStrength: switch (kind) {
        PowerUpKind.speed => tuning.speedFactor,
        PowerUpKind.overcharge => tuning.maximumPowerAmount,
        PowerUpKind.repulsor => tuning.repulsorForce,
        _ => 1,
      },
      healing: kind == PowerUpKind.apple ? tuning.arenaAppleHeal : 10,
      shieldHits: kind == PowerUpKind.goldenArmor ? 2 : 1,
      frozenDamageMultiplier: tuning.frozenDamageMultiplier,
      frozenCollisionDamage: tuning.frozenCollisionDamage,
      knockback:
          kind == PowerUpKind.energyWave || kind == PowerUpKind.omegaTendrils
          ? 1
          : 0,
      effectMode:
          kind == PowerUpKind.rocketLauncher || kind == PowerUpKind.grenade
          ? SkillVisualMode.vector
          : SkillVisualMode.sprite,
      soundCue: _defaultSoundFor(kind),
      yell: _defaultYellFor(kind),
      calloutStyle: kind.isTrap
          ? SkillCalloutStyle.special
          : SkillCalloutStyle.values[tuning.rarityOf(kind)!.index],
      bubbleType: kind == PowerUpKind.apple
          ? SkillBubbleType.speech
          : SkillBubbleType.shout,
    );
  }

  static String _defaultYellFor(PowerUpKind kind) => switch (kind) {
    PowerUpKind.pistol => 'BANG!',
    PowerUpKind.shotgun => 'BLAM!',
    PowerUpKind.gatling => 'RATATAT!',
    PowerUpKind.knife => 'SLASH!',
    PowerUpKind.shield => 'SHIELD BASH!',
    PowerUpKind.apple => 'YUM!',
    PowerUpKind.speed => 'ZOOM!',
    PowerUpKind.freeze => 'FREEZE!',
    PowerUpKind.mine => 'MINE SET!',
    PowerUpKind.magnet => 'MINE!',
    PowerUpKind.ghost => 'BOO!',
    PowerUpKind.grenade => 'FIRE IN THE HOLE!',
    PowerUpKind.sword => 'HIYAA!',
    PowerUpKind.hook => 'COME OVER HERE!',
    PowerUpKind.ricochetDisc => 'BANK SHOT!',
    PowerUpKind.orbitingFlail => 'WRECKING BALL!',
    PowerUpKind.threadHarpoon => 'GIVE IT HERE!',
    PowerUpKind.prismLaser => 'TASTE THE RAINBOW!',
    PowerUpKind.swapCannon => 'SWAP INCOMING!',
    PowerUpKind.phaseMine => 'NOW YOU SEE ME!',
    PowerUpKind.repulsor => 'BACK OFF!',
    PowerUpKind.timeBubble => 'TIME OUT!',
    PowerUpKind.vampire => 'I WANT YOUR POWER!',
    PowerUpKind.mirror => 'RETURN TO SENDER!',
    PowerUpKind.overcharge => 'MAXIMUM POWER!',
    PowerUpKind.gremlin => 'CHAOS MODE!',
    PowerUpKind.magneticField => 'NOTHING GETS THROUGH!',
    PowerUpKind.portal => 'WARP SPEED!',
    PowerUpKind.spikeWall => 'OUCH! SPIKES!',
    PowerUpKind.goldenArmor => 'GOLDEN GUARD!',
    PowerUpKind.bow => 'ARROWS, FLY!',
    PowerUpKind.stickyGoo => 'STUCK!',
    PowerUpKind.molotov => 'LIGHT IT UP!',
    PowerUpKind.rocketLauncher => 'TARGET LOCKED!',
    PowerUpKind.omegaTendrils => 'NO ONE ESCAPES!',
    PowerUpKind.boomerang => 'COMING BACK!',
    PowerUpKind.fireWall => 'BURNING BARRIER!',
    PowerUpKind.poisonSwamp => 'POISONED!',
    PowerUpKind.waterGun => 'SPLASH!',
    PowerUpKind.lightningStrikes => 'THUNDER, STRIKE!',
    PowerUpKind.earthquake => 'SHAKE THE EARTH!',
    PowerUpKind.tornado => 'TWIST AND SHOUT!',
    PowerUpKind.energyWave => 'KA-ME-HA-ME-HAAA!',
    PowerUpKind.flamethrower => 'BURN IT DOWN!',
    PowerUpKind.friedChicken => 'FULLY CHARGED!',
    PowerUpKind.sniperRifle => 'ONE SHOT.',
    PowerUpKind.busterSword => 'OMNISLASH!',
    PowerUpKind.ragingDemon => 'DIE ONE THOUSAND DEATHS!',
  };

  static String _defaultSoundFor(PowerUpKind kind) => switch (kind) {
    PowerUpKind.shotgun ||
    PowerUpKind.bow ||
    PowerUpKind.threadHarpoon => 'shotgun',
    PowerUpKind.gatling => 'gatling',
    PowerUpKind.knife ||
    PowerUpKind.sword ||
    PowerUpKind.orbitingFlail => 'slash',
    PowerUpKind.shield ||
    PowerUpKind.freeze ||
    PowerUpKind.repulsor ||
    PowerUpKind.magneticField ||
    PowerUpKind.goldenArmor => 'shield',
    PowerUpKind.grenade ||
    PowerUpKind.mine ||
    PowerUpKind.phaseMine ||
    PowerUpKind.molotov ||
    PowerUpKind.fireWall ||
    PowerUpKind.rocketLauncher ||
    PowerUpKind.lightningStrikes ||
    PowerUpKind.earthquake ||
    PowerUpKind.energyWave ||
    PowerUpKind.omegaTendrils => 'bomb',
    PowerUpKind.apple ||
    PowerUpKind.speed ||
    PowerUpKind.magnet ||
    PowerUpKind.ghost ||
    PowerUpKind.timeBubble ||
    PowerUpKind.vampire ||
    PowerUpKind.mirror ||
    PowerUpKind.overcharge ||
    PowerUpKind.gremlin => 'pickup',
    _ => 'shot',
  };

  static bool _same(SkillDefinition a, SkillDefinition b) =>
      a.toJson().toString() == b.toJson().toString();
}
