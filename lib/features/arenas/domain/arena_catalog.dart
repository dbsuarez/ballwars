import 'dart:convert';
import 'arena_definition.dart';
export 'arena_definition.dart';

class ArenaCatalog {
  const ArenaCatalog({this.arenas = const [], this.defaultId});
  static const maxArenas = 32;
  final List<ArenaDefinition> arenas;
  final String? defaultId;
  bool get isEmpty => arenas.isEmpty && defaultId == null;
  ArenaDefinition? find(String? id, {bool enabledOnly = true}) => arenas
      .where((a) => a.id == id && (!enabledOnly || a.enabled))
      .firstOrNull;
  Map<String, Object?> toJson() => {
    'version': 1,
    'arenas': [for (final a in arenas) a.toJson()],
    'default': defaultId,
  };
  static ArenaCatalog fromJson(Object? value) {
    if (value == null) return const ArenaCatalog();
    if (value is! Map ||
        value['version'] != 1 ||
        value['arenas'] is! List ||
        (value['arenas'] as List).length > maxArenas) {
      throw const FormatException('Invalid arena catalog.');
    }
    final arenas = (value['arenas'] as List)
        .map(ArenaDefinition.fromJson)
        .toList();
    if (arenas.map((a) => a.id).toSet().length != arenas.length) {
      throw const FormatException('Arena IDs must be unique.');
    }
    if (arenas.map((a) => a.name.toLowerCase()).toSet().length !=
        arenas.length) {
      throw const FormatException('An arena with this name already exists.');
    }
    final id = value['default'];
    if (id != null &&
        (id is! String || !arenas.any((a) => a.id == id && a.enabled))) {
      throw const FormatException('Default arena is unavailable.');
    }
    return ArenaCatalog(
      arenas: List.unmodifiable(arenas),
      defaultId: id as String?,
    );
  }

  ArenaCatalog withArena(ArenaDefinition arena) => fromJson(
    ArenaCatalog(
      arenas: [
        for (final a in arenas)
          if (a.id == arena.id) arena else a,
        if (!arenas.any((a) => a.id == arena.id)) arena,
      ],
      defaultId: defaultId == arena.id && !arena.enabled ? null : defaultId,
    ).toJson(),
  );
  ArenaCatalog without(String id) => ArenaCatalog(
    arenas: List.unmodifiable(arenas.where((a) => a.id != id)),
    defaultId: defaultId == id ? null : defaultId,
  );
  ArenaCatalog withDefault(String? id) =>
      fromJson(ArenaCatalog(arenas: arenas, defaultId: id).toJson());
  bool matchesStored(Object? value) =>
      jsonEncode(toJson()) == jsonEncode(fromJson(value).toJson());
}
