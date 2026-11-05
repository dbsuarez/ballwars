import 'package:characters/characters.dart';
import 'dart:convert';
import 'arena_theme.dart';
import 'arena_geometry.dart';

/// Immutable named-map defaults and appearance. Match geometry can still be
/// customized independently; replay snapshots never depend on the live catalog.
class ArenaDefinition {
  static const replayRevision = 9;
  static const maxNameCharacters = 40;
  static const maxNameBytes = 512;
  const ArenaDefinition({
    required this.id,
    required this.name,
    this.theme = ArenaDecoration.defaultArena,
    this.trapTheme = ArenaDecoration.defaultArena,
    this.shape = ArenaShape.circle,
    this.obstacle = CenterObstacle.none,
    this.obstacleScale = .22,
    this.floorColor,
    this.accentColor,
    this.rimColor,
    this.enabled = true,
    this.arenaTrapsEnabled = true,
  });
  final String id, name;
  final ArenaDecoration theme, trapTheme;
  final ArenaShape shape;
  final CenterObstacle obstacle;
  final double obstacleScale;
  final int? floorColor, accentColor, rimColor;
  final bool enabled;
  final bool arenaTrapsEnabled;
  String get trapCaption =>
      arenaTrapsEnabled ? trapTheme.hazardCaption : 'No arena traps';

  Map<String, Object> toJson() => {
    'version': 1,
    'id': id,
    'name': name.trim(),
    'theme': theme.name,
    'traps': trapTheme.name,
    'shape': shape.name,
    'obstacle': obstacle.name,
    'obstacleScale': obstacleScale,
    'enabled': enabled,
    'arenaTrapsEnabled': arenaTrapsEnabled,
    'floor': ?floorColor,
    'accent': ?accentColor,
    'rim': ?rimColor,
  };

  static ArenaDefinition fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Arena must be an object.');
    if (json['version'] != 1) {
      throw const FormatException(
        'Unsupported arena version. Update Ball Wars to open this arena.',
      );
    }
    final id = json['id'], name = json['name'], scale = json['obstacleScale'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id)) {
      throw const FormatException('Arena ID is invalid.');
    }
    if (name is! String ||
        name.trim().isEmpty ||
        name.trim().characters.length > maxNameCharacters ||
        utf8.encode(name.trim()).length > maxNameBytes ||
        RegExp(r'[\x00-\x1f]').hasMatch(name)) {
      throw const FormatException(
        'Enter an arena name between 1 and 40 characters on one line.',
      );
    }
    if (scale is! num || !scale.isFinite || scale < .12 || scale > .34) {
      throw const FormatException(
        'Center obstacle size must be between 12% and 34% of the arena radius.',
      );
    }
    if (json['enabled'] is! bool ||
        (json['arenaTrapsEnabled'] != null &&
            json['arenaTrapsEnabled'] is! bool)) {
      throw const FormatException(
        'Arena visibility or trap setting is invalid.',
      );
    }
    T choice<T extends Enum>(List<T> values, Object? raw) => values.firstWhere(
      (v) => v.name == raw,
      orElse: () => throw const FormatException('Unsupported arena option.'),
    );
    int? color(String key) {
      final c = json[key];
      if (c == null) return null;
      if (c is! int || c < 0xff000000 || c > 0xffffffff) {
        throw const FormatException('Arena colors must be opaque.');
      }
      return c;
    }

    return ArenaDefinition(
      id: id,
      name: name.trim(),
      theme: choice(ArenaDecoration.values, json['theme']),
      trapTheme: choice(ArenaDecoration.values, json['traps']),
      shape: choice(ArenaShape.values, json['shape']),
      obstacle: choice(CenterObstacle.values, json['obstacle']),
      obstacleScale: scale.toDouble(),
      enabled: json['enabled'] as bool,
      arenaTrapsEnabled: json['arenaTrapsEnabled'] as bool? ?? true,
      floorColor: color('floor'),
      accentColor: color('accent'),
      rimColor: color('rim'),
    );
  }

  ArenaDefinition validated() => fromJson(toJson());
  String encode() => base64Url
      .encode(utf8.encode(jsonEncode(validated().toJson())))
      .replaceAll('=', '');
  static ArenaDefinition decode(String value) {
    if (value.length > 2048) {
      throw const FormatException('Arena snapshot is too large.');
    }
    return fromJson(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(value)))),
    );
  }
}
