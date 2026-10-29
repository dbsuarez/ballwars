/// Presentation roles are independent of damage, targeting and collision rules.
enum SkillVisualRole { casting, impact, explosion }

enum EffectPlayback { once, loop, holdLast }

class EffectDefinition {
  const EffectDefinition({
    required this.id,
    required this.name,
    required this.spriteId,
    this.playback = EffectPlayback.once,
    this.durationSeconds,
    this.scale = 1,
    this.opacity = 1,
  });
  static const schemaVersion = 1;
  final String id, name, spriteId;
  final EffectPlayback playback;

  /// Null fits the existing event lifetime; explicit duration is cosmetic only.
  final double? durationSeconds;
  final double scale, opacity;

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'id': id,
    'name': name,
    'sprite': spriteId,
    'playback': playback.name,
    'duration': durationSeconds,
    'scale': scale,
    'opacity': opacity,
  };

  factory EffectDefinition.fromJson(Object? raw) {
    final json = _object(raw, 'Effect');
    if (json['version'] != schemaVersion) {
      throw const FormatException('Unsupported effect version.');
    }
    final playback = EffectPlayback.values
        .where((p) => p.name == json['playback'])
        .firstOrNull;
    if (playback == null) {
      throw const FormatException('Unknown effect playback.');
    }
    return EffectDefinition(
      id: _text(json, 'id', 128),
      name: _text(json, 'name', 80),
      spriteId: _text(json, 'sprite', 128),
      playback: playback,
      durationSeconds: json['duration'] == null
          ? null
          : _number(json, 'duration', .1, 10),
      scale: _number(json, 'scale', .1, 4),
      opacity: _number(json, 'opacity', 0, 1),
    );
  }
}

class SkillVisualBinding {
  const SkillVisualBinding({
    required this.effectId,
    this.scale = 1,
    this.opacity = 1,
  });
  final String effectId;
  final double scale, opacity;
  Map<String, Object?> toJson() => {
    'effect': effectId,
    'scale': scale,
    'opacity': opacity,
  };
  factory SkillVisualBinding.fromJson(Object? raw) {
    final json = _object(raw, 'Effect binding');
    return SkillVisualBinding(
      effectId: _text(json, 'effect', 128),
      scale: _number(json, 'scale', .1, 4),
      opacity: _number(json, 'opacity', 0, 1),
    );
  }
}

/// Fully resolved visual settings. Does not load assets or mutate simulation.
class ResolvedSkillEffect {
  const ResolvedSkillEffect({
    required this.spriteId,
    required this.scale,
    required this.opacity,
    required this.tint,
    required this.playback,
    this.durationSeconds,
  });
  final String spriteId;
  final double scale, opacity;
  final int tint;
  final EffectPlayback playback;
  final double? durationSeconds;
}

Map<SkillVisualRole, SkillVisualBinding> parseVisualBindings(Object? raw) {
  if (raw == null) return const {};
  final object = _object(raw, 'Visual bindings');
  if (object['version'] != 1 || object['bindings'] is! Map) {
    throw const FormatException('Unsupported visual bindings schema.');
  }
  final result = <SkillVisualRole, SkillVisualBinding>{};
  for (final entry in (object['bindings'] as Map).entries) {
    final role = SkillVisualRole.values
        .where((r) => r.name == entry.key)
        .firstOrNull;
    if (role == null) {
      throw FormatException('Unknown visual role: ${entry.key}.');
    }
    result[role] = SkillVisualBinding.fromJson(entry.value);
  }
  return Map.unmodifiable(result);
}

Map<String, EffectDefinition> parseEffectDefinitions(Object? raw) {
  if (raw == null) return const {};
  final object = _object(raw, 'Effect library');
  if (object['version'] != 1 ||
      object['definitions'] is! List ||
      (object['definitions'] as List).length > 256) {
    throw const FormatException(
      'Effect library needs version 1 and at most 256 definitions.',
    );
  }
  final result = <String, EffectDefinition>{};
  for (final rawDefinition in object['definitions'] as List) {
    final effect = EffectDefinition.fromJson(rawDefinition);
    if (result.containsKey(effect.id)) {
      throw FormatException('Duplicate effect ID: ${effect.id}.');
    }
    result[effect.id] = effect;
  }
  return Map.unmodifiable(result);
}

Map _object(Object? raw, String label) {
  if (raw is! Map) throw FormatException('$label must be an object.');
  return raw;
}

String _text(Map json, String key, int maximum) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    throw FormatException('Invalid effect $key.');
  }
  return value.trim();
}

double _number(Map json, String key, double minimum, double maximum) {
  final value = json[key];
  if (value is! num || !value.isFinite || value < minimum || value > maximum) {
    throw FormatException('Effect $key must be between $minimum and $maximum.');
  }
  return value.toDouble();
}
