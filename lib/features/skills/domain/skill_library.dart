import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';

enum SkillVisualMode { sprite, vector }

class SkillDefinition {
  const SkillDefinition({
    required this.id,
    required this.name,
    required this.baseKind,
    this.enabled = true,
    this.custom = false,
    this.arsenalDamage,
    this.allOutDamage,
    this.durationSeconds,
    this.projectileCount,
    this.projectileSpeed,
    this.spreadDegrees,
    this.maxBounces,
    this.knockback = 0,
    this.spriteMode = SkillVisualMode.sprite,
    this.effectMode = SkillVisualMode.sprite,
    this.soundCue = 'default',
  });

  final String id;
  final String name;
  final PowerUpKind baseKind;
  final bool enabled;
  final bool custom;
  final double? arsenalDamage;
  final int? allOutDamage;
  final double? durationSeconds;
  final int? projectileCount;
  final double? projectileSpeed;
  final double? spreadDegrees;
  final int? maxBounces;
  final double knockback;
  final SkillVisualMode spriteMode;
  final SkillVisualMode effectMode;
  final String soundCue;

  SkillDefinition copyWith({
    String? id,
    String? name,
    bool? enabled,
    bool? custom,
    double? arsenalDamage,
    int? allOutDamage,
    double? durationSeconds,
    int? projectileCount,
    double? projectileSpeed,
    double? spreadDegrees,
    int? maxBounces,
    double? knockback,
    SkillVisualMode? spriteMode,
    SkillVisualMode? effectMode,
    String? soundCue,
  }) => SkillDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    baseKind: baseKind,
    enabled: enabled ?? this.enabled,
    custom: custom ?? this.custom,
    arsenalDamage: arsenalDamage ?? this.arsenalDamage,
    allOutDamage: allOutDamage ?? this.allOutDamage,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    projectileCount: projectileCount ?? this.projectileCount,
    projectileSpeed: projectileSpeed ?? this.projectileSpeed,
    spreadDegrees: spreadDegrees ?? this.spreadDegrees,
    maxBounces: maxBounces ?? this.maxBounces,
    knockback: knockback ?? this.knockback,
    spriteMode: spriteMode ?? this.spriteMode,
    effectMode: effectMode ?? this.effectMode,
    soundCue: soundCue ?? this.soundCue,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'base': baseKind.name,
    'enabled': enabled,
    'custom': custom,
    if (arsenalDamage != null) 'arsenal_damage': arsenalDamage,
    if (allOutDamage != null) 'all_out_damage': allOutDamage,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    if (projectileCount != null) 'projectile_count': projectileCount,
    if (projectileSpeed != null) 'projectile_speed': projectileSpeed,
    if (spreadDegrees != null) 'spread_degrees': spreadDegrees,
    if (maxBounces != null) 'max_bounces': maxBounces,
    'knockback': knockback,
    'sprite_mode': spriteMode.name,
    'effect_mode': effectMode.name,
    'sound_cue': soundCue,
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
      durationSeconds: decimal('duration_seconds'),
      projectileCount: integer('projectile_count'),
      projectileSpeed: decimal('projectile_speed'),
      spreadDegrees: decimal('spread_degrees'),
      maxBounces: integer('max_bounces'),
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
    ).validated();
  }

  SkillDefinition validated() => copyWith(
    name: name.trim().substring(0, name.trim().length.clamp(1, 40)),
    arsenalDamage: arsenalDamage?.clamp(0, 500),
    allOutDamage: allOutDamage?.clamp(0, 360),
    durationSeconds: durationSeconds?.clamp(0.1, 60),
    projectileCount: projectileCount?.clamp(1, 100),
    projectileSpeed: projectileSpeed?.clamp(0.1, 10),
    spreadDegrees: spreadDegrees?.clamp(0, 360),
    maxBounces: maxBounces?.clamp(0, 20),
    knockback: knockback.clamp(0, 10),
  );
}

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

  bool get isDefault => overrides.isEmpty && custom.isEmpty;

  SkillDefinition builtIn(PowerUpKind kind, PowerUpConfig tuning) =>
      overrides['builtin.${kind.name}'] ?? _defaultFor(kind, tuning);

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

  PowerUpConfig applyTo(PowerUpConfig tuning) {
    var result = tuning;
    for (final kind in PowerUpKind.values) {
      final skill = builtIn(kind, tuning);
      final explicitlyConfigured = overrides.containsKey(skill.id);
      if (skill.arsenalDamage != null &&
          PowerUpConfig.damageKinds.contains(kind)) {
        result = result.withValue('dmg.${kind.name}', skill.arsenalDamage!);
      }
      if (skill.allOutDamage != null &&
          PowerUpConfig.damageKinds.contains(kind)) {
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

  factory SkillLibrary.fromJson(Object? value) {
    if (value is! Map) return defaults;
    final overrides = <String, SkillDefinition>{};
    final rawOverrides = value['overrides'];
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final definition = SkillDefinition.fromJson(entry.value);
        if (entry.key is String && definition != null && !definition.custom) {
          overrides[entry.key as String] = definition;
        }
      }
    }
    final custom = <SkillDefinition>[];
    final rawCustom = value['custom'];
    if (rawCustom is List) {
      for (final raw in rawCustom) {
        final definition = SkillDefinition.fromJson(raw);
        if (definition != null && definition.custom) custom.add(definition);
      }
    }
    return SkillLibrary(
      version: (value['version'] as num?)?.toInt().clamp(1, 100) ?? 1,
      overrides: Map.unmodifiable(overrides),
      custom: List.unmodifiable(custom),
    );
  }

  static SkillDefinition _defaultFor(PowerUpKind kind, PowerUpConfig tuning) {
    final damaging = PowerUpConfig.damageKinds.contains(kind);
    final duration = switch (kind) {
      PowerUpKind.speed => tuning.speedSteps / 60,
      PowerUpKind.freeze => tuning.freezeSteps / 60,
      PowerUpKind.ghost => tuning.ghostSteps / 60,
      PowerUpKind.repulsor ||
      PowerUpKind.timeBubble ||
      PowerUpKind.vampire ||
      PowerUpKind.overcharge ||
      PowerUpKind.magneticField => 3.0,
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
      knockback:
          kind == PowerUpKind.energyWave || kind == PowerUpKind.omegaTendrils
          ? 1
          : 0,
      soundCue: kind.name,
    );
  }

  static bool _same(SkillDefinition a, SkillDefinition b) =>
      a.toJson().toString() == b.toJson().toString();
}
