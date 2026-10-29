import 'dart:convert';
import '../../skills/domain/skill_library.dart';
import '../../arena_simulation/domain/power_up_config.dart';

/// No executable code or arbitrary URLs: just bounded immutable sprite IDs.
class ReplayAssets {
  static bool pinned(String id) => RegExp(
    r'^(custom\.[a-f0-9-]{36}~[a-f0-9-]{36}\.[a-z0-9-]{1,40}|built\.[a-f0-9]{40}\..{1,80})$',
  ).hasMatch(id);
  static Set<String> references(SkillLibrary library) => {
    for (final skill in library.all(PowerUpConfig.defaults))
      ...library.spriteReferences(skill).where(pinned),
    for (final effect in library.effects.values)
      if (pinned(effect.spriteId)) effect.spriteId,
  };
  static String? encode(
    SkillLibrary library,
    Map<String, String> revisions, {
    Map<String, Object> embedded = const {},
  }) {
    final entries = {
      ...revisions,
      for (final id in references(library))
        if (!revisions.values.contains(id)) id: id,
    };
    if (entries.isEmpty) return null;
    if (entries.length > 1024 ||
        entries.entries.any((e) => e.key.length > 128 || !pinned(e.value))) {
      throw const FormatException('Invalid replay artwork dependencies.');
    }
    final encoded = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'version': 1,
              'sprites': entries,
              if (embedded.isNotEmpty) 'embedded': embedded,
            }),
          ),
        )
        .replaceAll('=', '');
    if (encoded.length > 400000) {
      throw const FormatException('Replay artwork manifest is too large.');
    }
    return encoded;
  }

  static ({Map<String, String> ids, Map<String, Object> embedded})? decode(
    String? encoded,
    SkillLibrary library,
  ) {
    if (encoded == null) {
      return references(library).isEmpty
          ? (ids: const {}, embedded: const {})
          : null;
    }
    if (encoded.length > 400000) return null;
    try {
      final j = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      );
      if (j is! Map || j['version'] != 1 || j['sprites'] is! Map) return null;
      final raw = j['sprites'] as Map;
      if (raw.length > 1024 ||
          raw.entries.any(
            (e) =>
                e.key is! String ||
                (e.key as String).length > 128 ||
                e.value is! String ||
                !pinned(e.value),
          )) {
        return null;
      }
      final result = Map<String, String>.from(raw);
      if (!result.values.toSet().containsAll(references(library))) return null;
      final embedded = j['embedded'] ?? {};
      if (embedded is! Map ||
          embedded.length > 128 ||
          embedded.entries.any(
            (e) => !result.values.contains(e.key) || e.value is! Map,
          )) {
        return null;
      }
      return (
        ids: Map<String, String>.unmodifiable(result),
        embedded: Map<String, Object>.from(embedded),
      );
    } catch (_) {
      return null;
    }
  }
}
