import '../../../core/sprites/sprite_registry.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../skills/domain/skill_library.dart';
import 'custom_sprite_loader.dart';

/// One dependency barrier shared by matches, demos and exports.
class SkillSpriteReadiness {
  static CustomSpriteLoader? loader;
  static final _historical = CustomSpriteLoader(null);
  static Map<String, String> freezeIds(Iterable<String> ids) {
    final result = <String, String>{};
    for (final id in ids) {
      if (!SpriteRegistry.has(id)) continue;
      final custom = SpriteRegistry.frozenIds[id];
      if (custom != null) {
        result[id] = custom;
        continue;
      }
      if (!id.startsWith('custom.') &&
          !id.startsWith('built.') &&
          RegExp(r'^[a-f0-9]{40}$').hasMatch(SpriteRegistry.assetRevision)) {
        final target = 'built.${SpriteRegistry.assetRevision}.$id';
        if (target.length > 128) continue;
        SpriteRegistry.alias(
          id,
          target,
          'built.${SpriteRegistry.assetRevision}',
        );
        result[id] = target;
      }
    }
    return result;
  }

  static Set<String> dependencies({
    required SkillLibrary library,
    required PowerUpConfig tuning,
    Set<PowerUpKind>? kinds,
    Set<String>? customIds,
    bool includeTraps = true,
  }) {
    final found = <String>{};
    final visited = <String>{};
    void visit(SkillDefinition skill) {
      if (!visited.add(skill.id)) return;
      found.addAll(library.activeSpriteReferences(skill));
      for (final binding in skill.visualBindings.values) {
        if (!library.effects.containsKey(binding.effectId)) {
          found.add('effect:${binding.effectId}');
        }
      }
      final payload = skill.payloadSkillId == null
          ? null
          : library.byId(skill.payloadSkillId!, tuning);
      if (payload != null) visit(payload);
    }

    for (final skill in library.all(tuning)) {
      if (!skill.enabled) continue;
      if (skill.custom
          ? customIds == null || customIds.contains(skill.id)
          : kinds == null ||
                kinds.contains(skill.baseKind) ||
                (includeTraps && skill.baseKind.isTrap)) {
        visit(skill);
      }
    }
    return found;
  }

  /// Returns missing IDs; callers must explicitly offer fallback or report failure.
  static Future<Set<String>> prepare({
    required SkillLibrary library,
    required PowerUpConfig tuning,
    Set<PowerUpKind>? kinds,
    Set<String>? customIds,
    bool includeTraps = true,
    Iterable<String> extraIds = const [],
    Map<String, Object> embedded = const {},
  }) async {
    final ids = dependencies(
      library: library,
      tuning: tuning,
      kinds: kinds,
      customIds: customIds,
      includeTraps: includeTraps,
    );
    ids.addAll(extraIds);
    if (embedded.isNotEmpty) await SpriteRegistry.restoreEmbedded(embedded);
    if (ids.isEmpty) return {};
    if (ids.every(SpriteRegistry.has) && loader?.isLoading != true) return {};
    if (ids.any((id) => !id.startsWith('custom.'))) await SpriteRegistry.load();
    if (loader != null) {
      await loader!.load().timeout(const Duration(seconds: 15));
    }
    await (loader ?? _historical)
        .loadRevisions(ids)
        .timeout(const Duration(seconds: 30));
    return ids.where((id) => !SpriteRegistry.has(id)).toSet();
  }
}
