/// Presentation roles are independent of damage, targeting and collision rules.
enum SkillVisualRole { casting, impact, explosion, muzzle, trail }

enum EffectAttachment { automatic, owner, hand, impact, target, projectile }

enum EffectFacing { upright, direction, mirror }

List<EffectAttachment> effectAttachments(SkillVisualRole role) =>
    switch (role) {
      SkillVisualRole.casting || SkillVisualRole.muzzle => [
        EffectAttachment.automatic,
        EffectAttachment.owner,
        EffectAttachment.hand,
      ],
      SkillVisualRole.impact => [
        EffectAttachment.automatic,
        EffectAttachment.impact,
        EffectAttachment.target,
      ],
      SkillVisualRole.explosion => [
        EffectAttachment.automatic,
        EffectAttachment.impact,
      ],
      SkillVisualRole.trail => [
        EffectAttachment.automatic,
        EffectAttachment.projectile,
      ],
    };

enum EffectPlayback { once, loop, holdLast, natural }

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
  static const schemaVersion = 2;
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
    if (json['version'] != 1 && json['version'] != schemaVersion) {
      throw const FormatException('Unsupported effect version.');
    }
    final playback = EffectPlayback.values
        .where((p) => p.name == json['playback'])
        .firstOrNull;
    if (playback == null) {
      throw const FormatException('Unknown effect playback.');
    }
    if (playback == EffectPlayback.natural && json['duration'] == null) {
      throw const FormatException(
        'Natural playback needs the captured sprite duration.',
      );
    }
    return EffectDefinition(
      id: _text(json, 'id', 128),
      name: _text(json, 'name', 80),
      spriteId: _text(json, 'sprite', 128),
      playback: playback,
      durationSeconds: json['duration'] == null
          ? null
          : _number(json, 'duration', 1 / 60, 10),
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
    this.attachment = EffectAttachment.automatic,
    this.facing = EffectFacing.upright,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotationDegrees = 0,
    this.tint,
  });
  final EffectAttachment attachment;
  final EffectFacing facing;
  final double offsetX, offsetY, rotationDegrees;
  final int? tint;
  final String effectId;
  final double scale, opacity;
  SkillVisualBinding withEffect(String id) => SkillVisualBinding(
    effectId: id,
    scale: scale,
    opacity: opacity,
    attachment: attachment,
    facing: facing,
    offsetX: offsetX,
    offsetY: offsetY,
    rotationDegrees: rotationDegrees,
    tint: tint,
  );
  Map<String, Object?> toJson() => {
    'effect': effectId,
    'attachment': attachment.name,
    'facing': facing.name,
    'offset_x': offsetX,
    'offset_y': offsetY,
    'rotation': rotationDegrees,
    if (tint != null) 'tint': tint,
    'scale': scale,
    'opacity': opacity,
  };
  factory SkillVisualBinding.fromJson(Object? raw) {
    final json = _object(raw, 'Effect binding');
    return SkillVisualBinding(
      effectId: _text(json, 'effect', 128),
      attachment: _enum(
        json,
        'attachment',
        EffectAttachment.values,
        EffectAttachment.automatic,
      ),
      facing: _enum(json, 'facing', EffectFacing.values, EffectFacing.upright),
      offsetX: json['offset_x'] == null ? 0 : _number(json, 'offset_x', -5, 5),
      offsetY: json['offset_y'] == null ? 0 : _number(json, 'offset_y', -5, 5),
      rotationDegrees: json['rotation'] == null
          ? 0
          : _number(json, 'rotation', -360, 360),
      tint: _tint(json['tint']),
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
    this.attachment = EffectAttachment.automatic,
    this.facing = EffectFacing.upright,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotationDegrees = 0,
  });
  final EffectAttachment attachment;
  final EffectFacing facing;
  final double offsetX, offsetY, rotationDegrees;
  final String spriteId;
  final double scale, opacity;
  final int tint;
  final EffectPlayback playback;
  final double? durationSeconds;
}

Map<SkillVisualRole, SkillVisualBinding> parseVisualBindings(Object? raw) {
  if (raw == null) return const {};
  final object = _object(raw, 'Visual bindings');
  if ((object['version'] != 1 && object['version'] != 2) ||
      object['bindings'] is! Map) {
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
    final binding = SkillVisualBinding.fromJson(entry.value);
    if (!effectAttachments(role).contains(binding.attachment)) {
      throw FormatException('Attachment is not available for ${role.name}.');
    }
    result[role] = binding;
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

T _enum<T extends Enum>(Map json, String key, List<T> values, T fallback) {
  if (json[key] == null) return fallback;
  final value = values.where((v) => v.name == json[key]).firstOrNull;
  if (value == null) throw FormatException('Unknown effect $key.');
  return value;
}

int? _tint(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0 || value > 0xffffffff) {
    throw const FormatException('Invalid effect tint.');
  }
  return value;
}
