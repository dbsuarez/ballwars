import 'dart:convert';

import 'package:characters/characters.dart';

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

enum SkillCategory { weapon, powerUp, trap, arenaTrap }

enum SkillPurpose { attack, recovery, defense, hybrid, utility }

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
    this.category,
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
    this.pickupDisplayScale = 1,
    this.effectDisplayScale = 1,
    this.weaponGripInset = 0,
    this.weaponGripSide = 0,
    this.weaponGripRotation = 0,
    this.effectStrength = 1,
    this.healing = 10,
    this.shieldHits = 1,
    this.frozenDamageMultiplier = 1.5,
    this.frozenCollisionDamage = 5,
    this.knockback = 0,
    this.meleeReach = 0,
    this.spriteMode = SkillVisualMode.sprite,
    this.effectMode = SkillVisualMode.sprite,
    this.useGlobalEffectVisuals = true,
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
    this.spriteTint = 0xFFFFFFFF,
    this.screenShake = 0,
    this.handedness = SkillHandedness.carrierDefault,
    this.yell = '',
    this.calloutStyle = SkillCalloutStyle.normal,
    this.bubbleType = SkillBubbleType.shout,
    this.bubbleDurationSeconds = 1.2,
    this.explodesOnImpact = false,
    this.handEffectScale = 1,
    this.handEffectColor = 0xFFFFFFFF,
    this.handEffectDurationSeconds = 0.5,
    this.artworkKind,
    this.payloadSkillId,
    this.rarity,
    this.description = '',
    this.shellEnabled,
    this.shellSprite,
    this.shellSize = 1,
    this.shellRandomRest = true,
  });

  /// The guns that drop a spent casing per shot unless their skill says otherwise ([shellEnabled]).
  static const Set<PowerUpKind> defaultShellKinds = {
    PowerUpKind.pistol,
    PowerUpKind.shotgun,
    PowerUpKind.gatling,
    PowerUpKind.freeze,
  };

  /// Longest custom [description], in characters.
  static const int maxDescriptionLength = 160;

  final String id;
  final String name;
  final PowerUpKind baseKind;
  final SkillCategory? category;
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
  final double pickupDisplayScale;
  final double effectDisplayScale;
  final double weaponGripInset;

  /// Moves the held weapon across the aim line, in ball radii. Positive is
  /// the ball's right of the aim for the first hand; the second hand
  /// (dual wield) mirrors it.
  final double weaponGripSide;

  /// Degrees added to the held sprite's drawn angle, mirrored when the
  /// sprite flips, so a slanted sprite sits straight on both sides.
  final double weaponGripRotation;
  final double effectStrength;
  final double healing;
  final int shieldHits;
  final double frozenDamageMultiplier;
  final double frozenCollisionDamage;
  final double knockback;

  /// Contact weapons (blades, orbiting flail, shield bash, collision skills) strike an opponent up to
  /// this many of the holder's radii beyond touching. 0: only on a bump.
  final double meleeReach;
  final SkillVisualMode spriteMode;
  final SkillVisualMode effectMode;
  final bool useGlobalEffectVisuals;
  bool usesSpriteEffects({bool globalSprite = true}) => useGlobalEffectVisuals
      ? globalSprite
      : effectMode == SkillVisualMode.sprite;
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

  /// White keeps original artwork; other colors recolor luminance, preserving alpha.
  final int spriteTint;
  final double screenShake;
  final SkillHandedness handedness;
  final String yell;
  final SkillCalloutStyle calloutStyle;
  final SkillBubbleType bubbleType;
  final double bubbleDurationSeconds;
  final bool explodesOnImpact;
  final double handEffectScale;
  final int handEffectColor;
  final double handEffectDurationSeconds;

  /// Composition: the weapon artwork this skill shows when held and lying in the arena (its own tint still
  /// applies). Null: its own carrier's artwork. Only the look changes; [baseKind] keeps the equipment rules.
  final PowerUpKind? artworkKind;

  /// Composition: the stable id of the skill it fires (`builtin.<kind>` or `custom.<slug>`). Each shot is
  /// that skill's projectile, with its damage, flight, return, explosion, knockback, size, tint and sound;
  /// this skill keeps the trigger, aim, cooldown, callout and the number and spread of shots. Null: it
  /// fires its own projectile. See [SkillLibrary.resolvePayload] and [SkillLibrary.payloadProblem].
  final String? payloadSkillId;

  /// A custom skill's own tier (color, callout and spawn odds). Null: it follows its base kind's tier
  /// (`tier.<kind>` in the tuning), as custom skills did before they had one. Built-ins and traps never
  /// keep one ([validated] drops it). Read it through [SkillLibrary.rarityOf].
  final PowerUpRarity? rarity;

  /// The skill's own card text (Weapons dialog, Skill Management list), plain text on one line, at
  /// most [maxDescriptionLength] characters. Empty: the generated text is shown. A built-in keeps it
  /// in its override (admin edit); it is cosmetic, nothing in the match reads it.
  final String description;

  /// Whether firing drops a spent shell casing. Null: by kind ([defaultDropsShells]: a built-in or
  /// non-composed Pistol, Shotgun, Gatling or Freeze). Purely visual, never touches the match.
  final bool? shellEnabled;

  /// The [SpriteRegistry] id its casings are drawn with. Null (or an id that isn't loaded): the brass
  /// vector shell.
  final String? shellSprite;

  /// Casing size, times the brass shell's size (0.25 to 4).
  final double shellSize;

  /// A landed casing lies at a fixed pseudo-random angle (a hash of its number, no RNG draws). Off:
  /// the spin angle it had when it hit the floor.
  final bool shellRandomRest;

  /// What [shellEnabled] null means for this skill.
  bool get defaultDropsShells =>
      !isComposed && defaultShellKinds.contains(baseKind);

  /// Whether firing this skill drops shell casings.
  bool get dropsShells => shellEnabled ?? defaultDropsShells;

  /// Its held and arena artwork ([artworkKind], else its carrier).
  PowerUpKind get displayKind => artworkKind ?? baseKind;
  SkillCategory get resolvedCategory => category ?? _legacyCategory(baseKind);
  bool get canDamage =>
      (!isComposed &&
          ((arsenalDamage ?? 0) > 0 ||
              (allOutDamage ?? 0) > 0 ||
              (dotArsenalDamage ?? 0) > 0 ||
              (dotAllOutDamage ?? 0) > 0)) ||
      effectType == SkillEffectType.damage ||
      effectType == SkillEffectType.damageOverTime ||
      secondaryEffectType == SkillEffectType.damage ||
      secondaryEffectType == SkillEffectType.damageOverTime;
  bool get canHeal =>
      effectType == SkillEffectType.heal ||
      secondaryEffectType == SkillEffectType.heal;
  bool get canDefend =>
      effectType == SkillEffectType.shield ||
      secondaryEffectType == SkillEffectType.shield;
  SkillPurpose get purpose {
    final count = [
      canDamage,
      canHeal,
      canDefend,
    ].where((value) => value).length;
    if (count > 1) return SkillPurpose.hybrid;
    if (canDamage) return SkillPurpose.attack;
    if (canHeal) return SkillPurpose.recovery;
    if (canDefend) return SkillPurpose.defense;
    return SkillPurpose.utility;
  }

  /// Whether the match spawner can place this skill in the arena: picked up,
  /// fired after an aim, or used on contact. Timer, damage-taken and
  /// elimination skills work on every ball without a pickup.
  bool get spawnsInArena =>
      enabled &&
      (trigger == SkillTrigger.pickup ||
          trigger == SkillTrigger.aimedFire ||
          trigger == SkillTrigger.collision);

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
    SkillCategory? category,
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
    double? pickupDisplayScale,
    double? effectDisplayScale,
    double? weaponGripInset,
    double? weaponGripSide,
    double? weaponGripRotation,
    double? effectStrength,
    double? healing,
    int? shieldHits,
    double? frozenDamageMultiplier,
    double? frozenCollisionDamage,
    double? knockback,
    double? meleeReach,
    SkillVisualMode? spriteMode,
    SkillVisualMode? effectMode,
    bool? useGlobalEffectVisuals,
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
    int? spriteTint,
    double? screenShake,
    SkillHandedness? handedness,
    String? yell,
    SkillCalloutStyle? calloutStyle,
    SkillBubbleType? bubbleType,
    double? bubbleDurationSeconds,
    bool? explodesOnImpact,
    double? handEffectScale,
    int? handEffectColor,
    double? handEffectDurationSeconds,
    Object? artworkKind = _unset,
    Object? payloadSkillId = _unset,
    Object? rarity = _unset,
    String? description,
    Object? shellEnabled = _unset,
    Object? shellSprite = _unset,
    double? shellSize,
    bool? shellRandomRest,
  }) => SkillDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    baseKind: baseKind,
    category: category ?? this.category,
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
    pickupDisplayScale: pickupDisplayScale ?? this.pickupDisplayScale,
    effectDisplayScale: effectDisplayScale ?? this.effectDisplayScale,
    weaponGripInset: weaponGripInset ?? this.weaponGripInset,
    weaponGripSide: weaponGripSide ?? this.weaponGripSide,
    weaponGripRotation: weaponGripRotation ?? this.weaponGripRotation,
    effectStrength: effectStrength ?? this.effectStrength,
    healing: healing ?? this.healing,
    shieldHits: shieldHits ?? this.shieldHits,
    frozenDamageMultiplier:
        frozenDamageMultiplier ?? this.frozenDamageMultiplier,
    frozenCollisionDamage: frozenCollisionDamage ?? this.frozenCollisionDamage,
    knockback: knockback ?? this.knockback,
    meleeReach: meleeReach ?? this.meleeReach,
    spriteMode: spriteMode ?? this.spriteMode,
    effectMode: effectMode ?? this.effectMode,
    useGlobalEffectVisuals:
        useGlobalEffectVisuals ??
        (effectMode == null ? this.useGlobalEffectVisuals : false),
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
    spriteTint: spriteTint ?? this.spriteTint,
    screenShake: screenShake ?? this.screenShake,
    handedness: handedness ?? this.handedness,
    yell: yell ?? this.yell,
    calloutStyle: calloutStyle ?? this.calloutStyle,
    bubbleType: bubbleType ?? this.bubbleType,
    bubbleDurationSeconds: bubbleDurationSeconds ?? this.bubbleDurationSeconds,
    explodesOnImpact: explodesOnImpact ?? this.explodesOnImpact,
    handEffectScale: handEffectScale ?? this.handEffectScale,
    handEffectColor: handEffectColor ?? this.handEffectColor,
    handEffectDurationSeconds:
        handEffectDurationSeconds ?? this.handEffectDurationSeconds,
    artworkKind: identical(artworkKind, _unset)
        ? this.artworkKind
        : artworkKind as PowerUpKind?,
    payloadSkillId: identical(payloadSkillId, _unset)
        ? this.payloadSkillId
        : payloadSkillId as String?,
    rarity: identical(rarity, _unset) ? this.rarity : rarity as PowerUpRarity?,
    description: description ?? this.description,
    shellEnabled: identical(shellEnabled, _unset)
        ? this.shellEnabled
        : shellEnabled as bool?,
    shellSprite: identical(shellSprite, _unset)
        ? this.shellSprite
        : shellSprite as String?,
    shellSize: shellSize ?? this.shellSize,
    shellRandomRest: shellRandomRest ?? this.shellRandomRest,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'base': baseKind.name,
    'category': resolvedCategory.name,
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
    'pickup_display_scale': pickupDisplayScale,
    'effect_display_scale': effectDisplayScale,
    'weapon_grip_inset': weaponGripInset,
    // Left out at 0 (every built-in), so replay snapshots stay small.
    if (weaponGripSide != 0) 'weapon_grip_side': weaponGripSide,
    if (weaponGripRotation != 0) 'weapon_grip_rotation': weaponGripRotation,
    'effect_strength': effectStrength,
    'healing': healing,
    'shield_hits': shieldHits,
    'frozen_damage_multiplier': frozenDamageMultiplier,
    'frozen_collision_damage': frozenCollisionDamage,
    'knockback': knockback,
    if (meleeReach > 0) 'melee_reach': meleeReach,
    'sprite_mode': spriteMode.name,
    'effect_mode': effectMode.name,
    'use_global_effect_visuals': useGlobalEffectVisuals,
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
    'sprite_tint': spriteTint,
    'screen_shake': screenShake,
    'handedness': handedness.name,
    if (yell.isNotEmpty) 'yell': yell,
    'callout_style': calloutStyle.name,
    'bubble_type': bubbleType.name,
    'bubble_duration_seconds': bubbleDurationSeconds,
    'explodes_on_impact': explodesOnImpact,
    'hand_effect_scale': handEffectScale,
    'hand_effect_color': handEffectColor,
    'hand_effect_duration_seconds': handEffectDurationSeconds,
    if (artworkKind != null) 'artwork': artworkKind!.name,
    if (payloadSkillId != null) 'fires': payloadSkillId,
    if (rarity != null) 'rarity': rarity!.name,
    if (description.isNotEmpty) 'description': description,
    // Shell settings are left out at their defaults, so replay snapshots stay small.
    if (shellEnabled != null) 'shell': shellEnabled,
    if (shellSprite != null) 'shell_sprite': shellSprite,
    if (shellSize != 1) 'shell_size': shellSize,
    if (!shellRandomRest) 'shell_random_rest': false,
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
      category: nullableEnum('category', SkillCategory.values),
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
      pickupDisplayScale: decimal('pickup_display_scale') ?? 1,
      effectDisplayScale: decimal('effect_display_scale') ?? 1,
      weaponGripInset: decimal('weapon_grip_inset') ?? 0,
      weaponGripSide: decimal('weapon_grip_side') ?? 0,
      weaponGripRotation: decimal('weapon_grip_rotation') ?? 0,
      effectStrength: decimal('effect_strength') ?? 1,
      healing: decimal('healing') ?? 10,
      shieldHits: integer('shield_hits') ?? 1,
      frozenDamageMultiplier: decimal('frozen_damage_multiplier') ?? 1.5,
      frozenCollisionDamage: decimal('frozen_collision_damage') ?? 5,
      knockback: decimal('knockback') ?? 0,
      meleeReach: decimal('melee_reach') ?? 0,
      spriteMode: enumValue(
        'sprite_mode',
        SkillVisualMode.values,
        SkillVisualMode.sprite,
      ),
      useGlobalEffectVisuals:
          value['use_global_effect_visuals'] as bool? ??
          value['effect_mode'] != 'vector',
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
      spriteTint: integer('sprite_tint') ?? 0xFFFFFFFF,
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
      bubbleDurationSeconds: decimal('bubble_duration_seconds') ?? 1.2,
      explodesOnImpact: value['explodes_on_impact'] as bool? ?? false,
      handEffectScale: decimal('hand_effect_scale') ?? 1,
      handEffectColor: integer('hand_effect_color') ?? 0xFFFFFFFF,
      handEffectDurationSeconds: decimal('hand_effect_duration_seconds') ?? 0.5,
      artworkKind: nullableEnum('artwork', PowerUpKind.values),
      payloadSkillId: value['fires'] as String?,
      rarity: nullableEnum('rarity', PowerUpRarity.values),
      description: value['description'] is String
          ? value['description'] as String
          : '',
      shellEnabled: value['shell'] is bool ? value['shell'] as bool : null,
      shellSprite: value['shell_sprite'] is String
          ? value['shell_sprite'] as String
          : null,
      shellSize: value['shell_size'] is num
          ? (value['shell_size'] as num).toDouble()
          : 1,
      shellRandomRest: value['shell_random_rest'] is bool
          ? value['shell_random_rest'] as bool
          : true,
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
    pickupDisplayScale: pickupDisplayScale.clamp(0.25, 3),
    effectDisplayScale: effectDisplayScale.clamp(0.25, 3),
    weaponGripInset: weaponGripInset.clamp(-1.5, 1.5),
    weaponGripSide: weaponGripSide.clamp(-1.5, 1.5),
    weaponGripRotation: weaponGripRotation.clamp(-180.0, 180.0),
    effectStrength: effectStrength.clamp(0, 10),
    healing: healing.clamp(0, 500),
    shieldHits: shieldHits.clamp(0, 20),
    frozenDamageMultiplier: frozenDamageMultiplier.clamp(1, 5),
    frozenCollisionDamage: frozenCollisionDamage.clamp(0, 200),
    knockback: knockback.clamp(0, 100),
    meleeReach: meleeReach.clamp(0, 3),
    bubbleDurationSeconds: bubbleDurationSeconds.clamp(0.25, 10),
    repeatCount: repeatCount.clamp(1, 10),
    repeatIntervalSeconds: repeatIntervalSeconds.clamp(0.1, 10),
    startDelaySeconds: startDelaySeconds.clamp(0, 30),
    tickIntervalSeconds: tickIntervalSeconds.clamp(0.1, 10),
    cooldownSeconds: cooldownSeconds.clamp(0, 60),
    triggerIntervalSeconds: triggerIntervalSeconds.clamp(0.5, 120),
    effectColor: effectColor.clamp(0, 0xFFFFFFFF),
    spriteTint: spriteTint.clamp(0, 0xFFFFFFFF),
    screenShake: screenShake.clamp(0, 1),
    handEffectScale: handEffectScale.clamp(0.1, 4),
    handEffectColor: handEffectColor.clamp(0, 0xFFFFFFFF),
    handEffectDurationSeconds: handEffectDurationSeconds.clamp(0.1, 10),
    soundCue: soundCues.contains(soundCue) ? soundCue : 'shot',
    yell: yell.trim().substring(0, yell.trim().length.clamp(0, 60)),
    payloadSkillId: _cleanReference(payloadSkillId),
    rarity: custom && !baseKind.isTrap ? rarity : null,
    description: cleanDescription(description),
    shellSprite: _cleanReference(shellSprite),
    shellSize: shellSize.isFinite ? shellSize.clamp(0.25, 4) : 1,
  );

  /// [text] as a card description: whitespace and newlines collapsed to single spaces, trimmed and
  /// cut to [maxDescriptionLength] characters (grapheme clusters, as the editor's `maxLength`
  /// counts them), so an emoji is never split.
  static String cleanDescription(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final chars = flat.characters;
    return chars.length <= maxDescriptionLength
        ? flat
        : chars.take(maxDescriptionLength).toString().trimRight();
  }

  static String? _cleanReference(String? id) {
    final trimmed = id?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.length > 80) return null;
    return trimmed;
  }

  List<String> get compatibilityIssues {
    if (!isComposed) return const [];
    final issues = <String>[];
    if ((trigger == SkillTrigger.aimedFire ||
            trigger == SkillTrigger.collision) &&
        resolvedCategory != SkillCategory.weapon) {
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
    if (effects.contains(SkillEffectType.equipCarrier) &&
        resolvedCategory != SkillCategory.weapon) {
      issues.add('Equip carrier requires a weapon carrier.');
    }
    return List.unmodifiable(issues);
  }
}

SkillCategory _legacyCategory(PowerUpKind kind) => kind.isWeapon
    ? SkillCategory.weapon
    : kind.isTrap
    ? SkillCategory.trap
    : SkillCategory.powerUp;

const Object _unset = Object();

class SkillLibrary {
  const SkillLibrary({
    this.version = currentVersion,
    this.overrides = const {},
    this.custom = const [],
    this.calloutSeconds = defaultCalloutSeconds,
    this.skillsSetCallout = true,
    this.screenShake = defaultScreenShake,
    this.skillsSetScreenShake = true,
    this.weaponDisplayScale = 1,
    this.skillsSetWeaponDisplayScale = true,
    this.pickupDisplayScale = 1,
    this.skillsSetPickupDisplayScale = true,
    this.effectDisplayScale = 1,
    this.skillsSetEffectDisplayScale = true,
  });

  final int version;
  final Map<String, SkillDefinition> overrides;
  final List<SkillDefinition> custom;

  /// Global: how long a callout (speech bubble) stays up, in seconds. Used for every skill while
  /// [skillsSetCallout] is off.
  final double calloutSeconds;

  /// Global: "Let each skill set its own" callout duration ([SkillDefinition.bubbleDurationSeconds]).
  /// Off: every skill uses [calloutSeconds], and the per-skill field is disabled in the editor.
  final bool skillsSetCallout;

  static const double defaultCalloutSeconds = 1.2;

  /// Global: impact screen shake (0 none to 1 most), used for every skill while [skillsSetScreenShake]
  /// is off; on, each skill's own [SkillDefinition.screenShake] applies.
  final double screenShake;
  final bool skillsSetScreenShake;
  static const double defaultScreenShake = 0.3;

  /// Global sprite sizes (0.25..3): the equipped weapon, the field pickup and the effect artwork. Each is
  /// used for every skill while its "Let each skill set its own" switch is off; on (the default), each
  /// skill's own [SkillDefinition.weaponDisplayScale] / [SkillDefinition.pickupDisplayScale] /
  /// [SkillDefinition.effectDisplayScale] applies. Read them through [weaponDisplayScaleFor] etc.
  final double weaponDisplayScale;
  final bool skillsSetWeaponDisplayScale;
  final double pickupDisplayScale;
  final bool skillsSetPickupDisplayScale;
  final double effectDisplayScale;
  final bool skillsSetEffectDisplayScale;

  /// [skill]'s tier: a custom skill's own [SkillDefinition.rarity], else its base kind's tier in
  /// [tuning]. Null for traps, which have no tier. Every tier color, label, callout and spawn weight
  /// for a skill comes from here.
  static PowerUpRarity? rarityOf(SkillDefinition skill, PowerUpConfig tuning) =>
      skill.custom && skill.rarity != null && !skill.baseKind.isTrap
      ? skill.rarity
      : tuning.rarityOf(skill.baseKind);

  /// [skill] (a custom skill) with its own tier [rarity]; never touches the built-in's `tier.<kind>`.
  /// Its callout style moves with the tier when it was the old tier's style, so a skill whose callout
  /// was set apart from its tier keeps it.
  static SkillDefinition withOwnRarity(
    SkillDefinition skill,
    PowerUpRarity rarity,
    PowerUpConfig tuning,
  ) {
    if (!skill.custom || skill.baseKind.isTrap) return skill;
    final old = rarityOf(skill, tuning);
    final followsTier = old != null && skill.calloutStyle.index == old.index;
    return skill.copyWith(
      rarity: rarity,
      calloutStyle: followsTier
          ? SkillCalloutStyle.values[rarity.index]
          : skill.calloutStyle,
    );
  }

  /// [skill]'s impact screen shake.
  double screenShakeFor(SkillDefinition skill) =>
      skillsSetScreenShake ? skill.screenShake : screenShake;

  /// How long [skill]'s callout stays up.
  double calloutSecondsFor(SkillDefinition skill) =>
      skillsSetCallout ? skill.bubbleDurationSeconds : calloutSeconds;

  /// [skill]'s held weapon size.
  double weaponDisplayScaleFor(SkillDefinition skill) =>
      skillsSetWeaponDisplayScale
      ? skill.weaponDisplayScale
      : weaponDisplayScale;

  /// [skill]'s size lying in the arena.
  double pickupDisplayScaleFor(SkillDefinition skill) =>
      skillsSetPickupDisplayScale
      ? skill.pickupDisplayScale
      : pickupDisplayScale;

  /// [skill]'s effect artwork size.
  double effectDisplayScaleFor(SkillDefinition skill) =>
      skillsSetEffectDisplayScale
      ? skill.effectDisplayScale
      : effectDisplayScale;

  /// A copy with the global settings changed.
  SkillLibrary withGlobal({
    double? calloutSeconds,
    bool? skillsSetCallout,
    double? screenShake,
    bool? skillsSetScreenShake,
    double? weaponDisplayScale,
    bool? skillsSetWeaponDisplayScale,
    double? pickupDisplayScale,
    bool? skillsSetPickupDisplayScale,
    double? effectDisplayScale,
    bool? skillsSetEffectDisplayScale,
  }) => SkillLibrary(
    version: version,
    overrides: overrides,
    custom: custom,
    calloutSeconds: (calloutSeconds ?? this.calloutSeconds).clamp(0.25, 10),
    skillsSetCallout: skillsSetCallout ?? this.skillsSetCallout,
    screenShake: (screenShake ?? this.screenShake).clamp(0, 1),
    skillsSetScreenShake: skillsSetScreenShake ?? this.skillsSetScreenShake,
    weaponDisplayScale: (weaponDisplayScale ?? this.weaponDisplayScale).clamp(
      0.25,
      3,
    ),
    skillsSetWeaponDisplayScale:
        skillsSetWeaponDisplayScale ?? this.skillsSetWeaponDisplayScale,
    pickupDisplayScale: (pickupDisplayScale ?? this.pickupDisplayScale).clamp(
      0.25,
      3,
    ),
    skillsSetPickupDisplayScale:
        skillsSetPickupDisplayScale ?? this.skillsSetPickupDisplayScale,
    effectDisplayScale: (effectDisplayScale ?? this.effectDisplayScale).clamp(
      0.25,
      3,
    ),
    skillsSetEffectDisplayScale:
        skillsSetEffectDisplayScale ?? this.skillsSetEffectDisplayScale,
  );

  /// A copy with other skills, keeping the global settings.
  SkillLibrary _withSkills({
    Map<String, SkillDefinition>? overrides,
    List<SkillDefinition>? custom,
  }) => SkillLibrary(
    version: version,
    overrides: overrides ?? this.overrides,
    custom: custom ?? this.custom,
    calloutSeconds: calloutSeconds,
    skillsSetCallout: skillsSetCallout,
    screenShake: screenShake,
    skillsSetScreenShake: skillsSetScreenShake,
    weaponDisplayScale: weaponDisplayScale,
    skillsSetWeaponDisplayScale: skillsSetWeaponDisplayScale,
    pickupDisplayScale: pickupDisplayScale,
    skillsSetPickupDisplayScale: skillsSetPickupDisplayScale,
    effectDisplayScale: effectDisplayScale,
    skillsSetEffectDisplayScale: skillsSetEffectDisplayScale,
  );

  /// Writes the given values into every skill's own fields ("Apply to all skills" in the Global tab):
  /// each built-in through an override made from [builtIn], each custom skill in place. Null leaves that
  /// field alone; with no values this library is returned as is. Values are clamped like the editor's.
  /// Unlike the global switches this changes each skill, so it stays when a switch is turned back on.
  SkillLibrary applyToAll(
    PowerUpConfig tuning, {
    double? calloutSeconds,
    double? screenShake,
    double? weaponDisplayScale,
    double? pickupDisplayScale,
    double? effectDisplayScale,
  }) {
    if (calloutSeconds == null &&
        screenShake == null &&
        weaponDisplayScale == null &&
        pickupDisplayScale == null &&
        effectDisplayScale == null) {
      return this;
    }
    SkillDefinition apply(SkillDefinition skill) => skill.copyWith(
      bubbleDurationSeconds: calloutSeconds,
      screenShake: screenShake,
      weaponDisplayScale: weaponDisplayScale,
      pickupDisplayScale: pickupDisplayScale,
      effectDisplayScale: effectDisplayScale,
    );
    var result = this;
    for (final kind in PowerUpKind.values) {
      final current = result.builtIn(kind, tuning);
      final next = apply(current);
      // A built-in nobody edited that already has these values stays unedited: no no-op override
      // (under admin tuning it would differ from the factory default and freeze its numbers).
      if (!result.overrides.containsKey(current.id) &&
          _same(next.validated(), current)) {
        continue;
      }
      result = result.withDefinition(next, tuning);
    }
    return result._withSkills(
      custom: List.unmodifiable([
        for (final skill in result.custom) apply(skill).validated(),
      ]),
    );
  }

  static const SkillLibrary defaults = SkillLibrary();
  static const int currentVersion = 2;

  /// The version [toCompactJson] writes (replay snapshots). Saved libraries stay [currentVersion].
  static const int compactVersion = 3;
  static const int maxImportCharacters = 1000000;
  static const int maxImportedDefinitions = 512;
  static const int maxReplayCharacters = 48000;

  bool get isDefault =>
      overrides.isEmpty &&
      custom.isEmpty &&
      calloutSeconds == defaultCalloutSeconds &&
      skillsSetCallout &&
      screenShake == defaultScreenShake &&
      skillsSetScreenShake &&
      weaponDisplayScale == 1 &&
      skillsSetWeaponDisplayScale &&
      pickupDisplayScale == 1 &&
      skillsSetPickupDisplayScale &&
      effectDisplayScale == 1 &&
      skillsSetEffectDisplayScale;

  SkillDefinition builtIn(PowerUpKind kind, PowerUpConfig tuning) =>
      overrides['builtin.${kind.name}'] ?? _defaultFor(kind, tuning);

  /// Legacy-kind lookup. Custom skills are resolved by their stable ID and do
  /// not replace this built-in definition.
  SkillDefinition activeFor(PowerUpKind kind, PowerUpConfig tuning) =>
      builtIn(kind, tuning);

  SkillDefinition? byId(String id, PowerUpConfig tuning) {
    if (id.startsWith('builtin.')) {
      final kindName = id.substring('builtin.'.length);
      final kind = PowerUpKind.values
          .where((candidate) => candidate.name == kindName)
          .firstOrNull;
      return kind == null ? null : builtIn(kind, tuning);
    }
    return custom.where((skill) => skill.id == id).firstOrNull;
  }

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
      final next = [...custom];
      final index = next.indexWhere((item) => item.id == valid.id);
      if (index < 0) {
        next.add(valid);
      } else {
        next[index] = valid;
      }
      return _withSkills(custom: List.unmodifiable(next));
    }
    final next = Map<String, SkillDefinition>.of(overrides);
    // Compare with immutable factory defaults. [tuning] may already contain
    // this library's applied values after a settings reload; comparing against
    // it used to silently discard an edit as if it were the default.
    final original = _defaultFor(valid.baseKind, PowerUpConfig.defaults);
    if (_same(valid, original)) {
      next.remove(valid.id);
    } else {
      next[valid.id] = valid;
    }
    return _withSkills(overrides: Map.unmodifiable(next));
  }

  /// Built-in weapons that fire separate projectiles, so another skill can fire them. Beams, sprays and
  /// walls are left out: their built-in effect isn't a projectile.
  static bool isProjectileKind(PowerUpKind kind) =>
      kind.isGun && !_nonProjectileGuns.contains(kind);

  static const Set<PowerUpKind> _nonProjectileGuns = {
    PowerUpKind.fireWall,
    PowerUpKind.flamethrower,
    PowerUpKind.prismLaser,
    PowerUpKind.energyWave,
    PowerUpKind.waterGun,
    PowerUpKind.busterSword,
  };

  /// True when [skill] can be another skill's payload: a composed skill that delivers a projectile, or a
  /// built-in projectile weapon.
  static bool firesProjectiles(SkillDefinition skill) => skill.isComposed
      ? skill.delivery == SkillDelivery.projectile
      : isProjectileKind(skill.baseKind);

  /// The skills [skill] could fire: every projectile skill but itself.
  List<SkillDefinition> payloadCandidates(
    SkillDefinition skill,
    PowerUpConfig tuning,
  ) => [
    for (final candidate in all(tuning))
      if (candidate.id != skill.id && firesProjectiles(candidate)) candidate,
  ];

  /// What's wrong with [skill]'s fired-skill reference, or null when it has none or it's fine: the skill
  /// fires itself, the reference is missing or doesn't fire projectiles, it loops back, or [skill] can't
  /// fire anything (only aimed weapons can).
  String? payloadProblem(SkillDefinition skill, PowerUpConfig tuning) {
    final first = skill.payloadSkillId;
    if (first == null) return null;
    final aimed = skill.isComposed
        ? skill.trigger == SkillTrigger.aimedFire
        : isProjectileKind(skill.baseKind);
    if (!aimed) {
      return 'Only an aimed weapon can fire another skill.';
    }
    if (first == skill.id) return "A skill can't fire itself.";
    final path = [skill.name];
    final seen = {skill.id};
    String? id = first;
    while (id != null) {
      final next = byId(id, tuning);
      if (next == null) return 'The skill it fires ("$id") no longer exists.';
      path.add(next.name);
      if (!seen.add(next.id)) return 'Loop: ${path.join(' → ')}.';
      if (!firesProjectiles(next)) {
        return '${next.name} does not fire projectiles.';
      }
      id = next.payloadSkillId;
    }
    return null;
  }

  /// The definition each of [skill]'s shots carries: its fired skill (following chains: if A fires B and B
  /// fires C, A's shots are C), made a projectile definition if it's a built-in. Null when it fires its own
  /// projectile or the reference is broken ([payloadProblem]); the match then uses [skill] itself.
  SkillDefinition? resolvePayload(SkillDefinition skill, PowerUpConfig tuning) {
    if (skill.payloadSkillId == null || payloadProblem(skill, tuning) != null) {
      return null;
    }
    var current = skill;
    while (current.payloadSkillId != null) {
      current = byId(current.payloadSkillId!, tuning)!;
    }
    if (current.isComposed) return current;
    return current.copyWith(
      trigger: SkillTrigger.aimedFire,
      targeting: SkillTargeting.nearestOpponent,
      delivery: SkillDelivery.projectile,
      effectType: SkillEffectType.damage,
    );
  }

  SkillLibrary removeCustom(String id) => _withSkills(
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
    return _composeLegacyCustom(
      source.copyWith(id: id, name: name, custom: true, enabled: true),
    );
  }

  /// Older duplicates carried presentation values but no executable behavior,
  /// so runtime fell back to their carrier's hard-coded implementation. Give
  /// every custom definition an explicit shared-model behavior.
  static SkillDefinition _composeLegacyCustom(SkillDefinition skill) {
    if (!skill.custom || skill.isComposed) return skill;
    if (skill.baseKind.isWeapon) {
      final projectile = skill.baseKind.isGun;
      return skill.copyWith(
        trigger: projectile ? SkillTrigger.aimedFire : SkillTrigger.collision,
        targeting: SkillTargeting.nearestOpponent,
        delivery: projectile ? SkillDelivery.projectile : SkillDelivery.instant,
        effectType: SkillEffectType.damage,
      );
    }
    return skill.copyWith(
      trigger: SkillTrigger.pickup,
      targeting: skill.canHeal || skill.canDefend
          ? SkillTargeting.self
          : SkillTargeting.nearestOpponent,
      delivery: skill.resolvedCategory == SkillCategory.arenaTrap
          ? SkillDelivery.boundaryHazard
          : SkillDelivery.instant,
      effectType: skill.canHeal
          ? SkillEffectType.heal
          : skill.canDefend
          ? SkillEffectType.shield
          : SkillEffectType.damage,
    );
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
      final skill = builtIn(kind, tuning);
      final explicitlyConfigured = overrides.containsKey(skill.id);
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
    if (calloutSeconds != defaultCalloutSeconds)
      'callout_seconds': calloutSeconds,
    if (!skillsSetCallout) 'skills_set_callout': false,
    if (screenShake != defaultScreenShake) 'screen_shake': screenShake,
    if (!skillsSetScreenShake) 'skills_set_screen_shake': false,
    if (weaponDisplayScale != 1) 'weapon_display_scale': weaponDisplayScale,
    if (!skillsSetWeaponDisplayScale) 'skills_set_weapon_display_scale': false,
    if (pickupDisplayScale != 1) 'pickup_display_scale': pickupDisplayScale,
    if (!skillsSetPickupDisplayScale) 'skills_set_pickup_display_scale': false,
    if (effectDisplayScale != 1) 'effect_display_scale': effectDisplayScale,
    if (!skillsSetEffectDisplayScale) 'skills_set_effect_display_scale': false,
  };

  /// [toJson] with each built-in override stored as a diff against its factory default
  /// (`_defaultFor(kind, PowerUpConfig.defaults)`): `id` and `base`, then only the keys whose value
  /// differs (a key the default has and the override lacks is written as null). Marked
  /// [compactVersion], which apps from before it reject instead of misreading; [SkillLibrary.fromJson]
  /// reads both forms to the same library. Used for replay snapshots; saved libraries keep [toJson].
  Map<String, Object?> toCompactJson() => {
    ...toJson(),
    'version': compactVersion,
    'overrides': {
      for (final entry in overrides.entries) entry.key: _diff(entry.value),
    },
    'custom': [for (final item in custom) _diff(item)],
  };

  /// What [_diff] compares [skill] with: a built-in's factory default, or for a custom skill a
  /// bare definition with the constructor's defaults.
  static Map<String, Object?> _baseline(PowerUpKind kind, Map skill) =>
      skill['custom'] == true
      ? SkillDefinition(
          id: '${skill['id']}',
          name: '${skill['name']}',
          baseKind: kind,
          custom: true,
        ).toJson()
      : _defaultFor(kind, PowerUpConfig.defaults).toJson();

  static Map<String, Object?> _diff(SkillDefinition skill) {
    final full = skill.toJson();
    final base = _baseline(skill.baseKind, full);
    return {
      'id': full['id'],
      'name': full['name'],
      'base': full['base'],
      if (skill.custom) 'custom': true,
      for (final entry in full.entries)
        if (!const {'id', 'name', 'base', 'custom'}.contains(entry.key) &&
            jsonEncode(entry.value) != jsonEncode(base[entry.key]))
          entry.key: entry.value,
      for (final key in base.keys)
        if (!full.containsKey(key)) key: null,
    };
  }

  /// A compact skill ([toCompactJson]) laid over its baseline, as the full JSON
  /// [SkillDefinition.fromJson] reads. Anything that isn't a diff of a known kind is returned as
  /// is, so it fails the usual checks.
  static Object? _expand(Object? raw) {
    if (raw is! Map) return raw;
    final kind = PowerUpKind.values
        .where((candidate) => candidate.name == raw['base'])
        .firstOrNull;
    if (kind == null || raw['id'] is! String) return raw;
    final merged = <String, Object?>{..._baseline(kind, raw)};
    for (final entry in raw.entries) {
      if (entry.value == null) {
        merged.remove(entry.key);
      } else {
        merged['${entry.key}'] = entry.value;
      }
    }
    return merged;
  }

  static bool _isCompact(Map value) {
    final version = value['version'];
    return version is num && version.toInt() >= compactVersion;
  }

  /// Whether [stored] (this library as the server returned it) holds the
  /// same skills. Postgres jsonb sorts object keys, so the JSON text order
  /// differs; both sides are read back the same way and compared by content.
  bool matchesStored(Object? stored) {
    if (stored is! Map) return false;
    final mine = SkillLibrary.fromJson(jsonDecode(jsonEncode(toJson())));
    return jsonEncode(_sortedKeys(SkillLibrary.fromJson(stored).toJson())) ==
        jsonEncode(_sortedKeys(mine.toJson()));
  }

  static Object? _sortedKeys(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: _sortedKeys(value[key])};
    }
    if (value is List) return [for (final item in value) _sortedKeys(item)];
    return value;
  }

  /// Immutable skill snapshot embedded in replay links. The replay keeps the
  /// exact definitions that were active when it was created, so later admin
  /// edits cannot change an old match.
  ///
  /// The snapshot is the full form ([toJson], version 2, frozen definitions, readable by older apps)
  /// whenever it fits [maxReplayCharacters]. Only a library too large for that (say, every built-in
  /// edited) falls back to the compact form ([toCompactJson], version 3), whose unedited fields come
  /// from the factory defaults at decode time.
  String? encodeReplay() {
    if (isDefault) return null;
    var source = jsonEncode(toJson());
    if (source.length > maxReplayCharacters) {
      source = jsonEncode(toCompactJson());
    }
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
    final compact = _isCompact(value);
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final definition = SkillDefinition.fromJson(
          compact ? _expand(entry.value) : entry.value,
        );
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
        final definition = SkillDefinition.fromJson(
          compact ? _expand(raw) : raw,
        );
        if (definition != null && definition.custom) {
          final restored = _composeLegacyCustom(
            definition.yell.isEmpty && !definition.isComposed
                ? definition.copyWith(
                    yell: _defaultYellFor(definition.baseKind),
                  )
                : definition,
          );
          custom.add(restored);
        }
      }
    }
    final callout = value['callout_seconds'];
    final shake = value['screen_shake'];
    double scale(String key) {
      final raw = value[key];
      return raw is num && raw.isFinite ? raw.toDouble().clamp(0.25, 3) : 1;
    }

    return SkillLibrary(
      version: currentVersion,
      overrides: Map.unmodifiable(overrides),
      custom: List.unmodifiable(custom),
      calloutSeconds: callout is num && callout.isFinite
          ? callout.toDouble().clamp(0.25, 10)
          : defaultCalloutSeconds,
      skillsSetCallout: value['skills_set_callout'] as bool? ?? true,
      screenShake: shake is num && shake.isFinite
          ? shake.toDouble().clamp(0, 1)
          : defaultScreenShake,
      skillsSetScreenShake: value['skills_set_screen_shake'] as bool? ?? true,
      weaponDisplayScale: scale('weapon_display_scale'),
      skillsSetWeaponDisplayScale:
          value['skills_set_weapon_display_scale'] as bool? ?? true,
      pickupDisplayScale: scale('pickup_display_scale'),
      skillsSetPickupDisplayScale:
          value['skills_set_pickup_display_scale'] as bool? ?? true,
      effectDisplayScale: scale('effect_display_scale'),
      skillsSetEffectDisplayScale:
          value['skills_set_effect_display_scale'] as bool? ?? true,
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
    if (version is! num ||
        version.toInt() < 1 ||
        version.toInt() > compactVersion) {
      throw FormatException(
        'Unsupported skill-library version. Expected 1-$compactVersion.',
      );
    }
    final compact = _isCompact(decoded);
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
      final skill = SkillDefinition.fromJson(
        compact ? _expand(entry.value) : entry.value,
      );
      if (entry.key is! String || skill == null || skill.custom) {
        throw const FormatException('An override definition is invalid.');
      }
    }
    for (final value in custom) {
      final skill = SkillDefinition.fromJson(compact ? _expand(value) : value);
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
      category: _legacyCategory(kind),
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
      weaponGripInset: kind.defaultGripInset,
      effectStrength: switch (kind) {
        PowerUpKind.speed => tuning.speedFactor,
        PowerUpKind.overcharge => tuning.maximumPowerAmount,
        PowerUpKind.repulsor => tuning.repulsorForce,
        _ => 1,
      },
      handEffectScale: kind == PowerUpKind.tornado ? 1.15 : 1,
      handEffectColor: kind == PowerUpKind.tornado
          ? 0xFFD8F8FF
          : kind == PowerUpKind.fireWall
          ? 0xFFFF6422
          : 0xFFFFFFFF,
      handEffectDurationSeconds: kind == PowerUpKind.tornado ? 0.5 : 0.65,
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
      screenShake: kind.impactWeight,
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
    PowerUpKind.shadowClone => 'KAGE BUNSHIN NO JUTSU!',
  };

  static String _defaultSoundFor(PowerUpKind kind) => switch (kind) {
    PowerUpKind.shotgun ||
    PowerUpKind.bow ||
    PowerUpKind.threadHarpoon => 'shotgun',
    PowerUpKind.gatling => 'gatling',
    PowerUpKind.knife ||
    PowerUpKind.sword ||
    PowerUpKind.orbitingFlail ||
    PowerUpKind.shadowClone => 'slash',
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
