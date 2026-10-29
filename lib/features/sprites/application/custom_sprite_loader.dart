import 'dart:convert';
import '../../../core/sprites/sprite_atlas.dart';
import 'package:flutter/foundation.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../data/sprite_atlas_repository.dart';

class CustomSpriteLoader {
  CustomSpriteLoader(this.repository, {Future<Uint8List> Function(Uri)? fetch})
    : fetch = fetch ?? fetchSpriteSheet;
  final SpriteAtlasRepository? repository;
  final Future<Uint8List> Function(Uri) fetch;
  final List<String> problems = [];
  static final Set<String> _loaded = {};
  static final Map<String, String> _revisions = {};
  Future<void> loadRevisions(Set<String> ids) async {
    final requested = ids.where((id) => !SpriteRegistry.has(id)).toSet();
    final groups = <String, Set<String>>{};
    for (final id in requested) {
      final custom = RegExp(
        r'^custom\.([a-f0-9-]{36})~([a-f0-9-]{36})\.([a-z0-9-]{1,40})$',
      ).firstMatch(id);
      if (custom != null) {
        (groups['custom.${custom[1]}~${custom[2]}'] ??= {}).add(id);
      } else if (RegExp(r'^built\.[a-f0-9]{40}\.').hasMatch(id)) {
        (groups[id.substring(0, 46)] ??= {}).add(id);
      }
    }
    for (final group in groups.entries) {
      try {
        if (group.key.startsWith('custom.')) {
          final parts = group.key.substring(7).split('~');
          if (repository is! SpriteRevisionRepository) {
            throw StateError('Revision archive is unavailable.');
          }
          final a = await (repository as SpriteRevisionRepository).loadRevision(
            parts[0],
            parts[1],
          );
          if (a == null) throw StateError('Archived artwork was not found.');
          await _register(a, prefix: group.key);
        } else {
          final commit = group.key.substring(6);
          if (commit == SpriteRegistry.assetRevision) {
            await SpriteRegistry.load();
            for (final id in group.value) {
              SpriteRegistry.alias(id.substring(47), id, group.key);
            }
          } else {
            await _bundledRevision(commit, group.value);
          }
        }
      } catch (e) {
        problems.add('Historical artwork ${group.key}: $e');
      }
    }
    SpriteRegistry.trimCache();
  }

  Future<void> _bundledRevision(String commit, Set<String> ids) async {
    Future<Uint8List> read(String path) async {
      if (!path.startsWith('assets/sprites/') ||
          path.contains('..') ||
          path.contains('://')) {
        throw const FormatException('Invalid historical asset path.');
      }
      return fetch(
        Uri.parse(
          'https://raw.githubusercontent.com/dbsuarez/ballwars/$commit/$path',
        ),
      );
    }

    final index = jsonDecode(utf8.decode(await read(SpriteRegistry.indexPath)));
    if (index is! List || index.length > 128) {
      throw const FormatException('Invalid historical atlas index.');
    }
    for (final path in index) {
      if (path is! String) throw const FormatException('Invalid atlas path.');
      final atlas = SpriteAtlas.parse(
        jsonDecode(utf8.decode(await read(path))),
      );
      final selected = {
        for (final e in atlas.sprites.entries)
          if (ids.contains('built.$commit.${e.key}')) e.key: e.value,
      };
      if (selected.isEmpty) continue;
      if (selected.values.any(
        (s) => s.output > 1024 || s.height > 1024 || s.frames.length > 256,
      )) {
        throw const FormatException('Historical atlas exceeds limits.');
      }
      final image = await validateSpriteSheet(
        await read(atlas.sheet),
        'image/png',
      );
      try {
        await SpriteRegistry.registerHistorical(
          SpriteAtlas(
            sheet: atlas.sheet,
            sprites: selected,
            sheetSize: atlas.sheetSize,
          ),
          image,
          commit,
        );
      } finally {
        image.dispose();
      }
    }
  }

  Future<void> _register(CustomAtlas a, {required String prefix}) async {
    if (a.atlas.sprites.isEmpty ||
        a.atlas.sprites.length > 64 ||
        a.atlas.sprites.values.fold<int>(0, (n, s) => n + s.frames.length) >
            256 ||
        a.atlas.sprites.values.any((s) => s.output > 256 || s.height > 256)) {
      throw const FormatException('Custom atlas exceeds limits.');
    }
    final estimated = a.atlas.sprites.values.fold<int>(
      0,
      (n, s) => n + s.output * s.height * s.frames.length * 4,
    );
    if (SpriteRegistry.decodedBytes + estimated > 384 * 1048576) {
      throw const FormatException(
        'Required artwork exceeds the 384 MB safety limit. Reduce frames or enabled assets.',
      );
    }
    final bytes = await fetch(Uri.parse(a.sheetUrl));
    final image = await validateSpriteSheet(
      bytes,
      a.sheetPath.endsWith('.webp') ? 'image/webp' : 'image/png',
    );
    try {
      await SpriteRegistry.register(
        a.atlas,
        image,
        idPrefix: prefix,
        label: a.name,
      );
    } finally {
      image.dispose();
    }
  }

  void _aliases(CustomAtlas a) {
    final revision = a.sheetPath.split('/').last.split('.').first;
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(revision)) return;
    for (final name in a.atlas.sprites.keys) {
      final source = 'custom.${a.id}.$name',
          target = 'custom.${a.id}~$revision.$name';
      SpriteRegistry.alias(source, target, 'custom.${a.id}~$revision');
      SpriteRegistry.frozenIds[source] = target;
    }
  }

  Future<void>? _inFlight;
  bool get isLoading => _inFlight != null;
  Future<void> load() =>
      _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    problems.clear();
    try {
      if (repository == null) return;
      final atlases = await repository!.list();
      final present = atlases.map((a) => 'custom.${a.id}').toSet();
      for (final old in _loaded.difference(present)) {
        SpriteRegistry.unregister(old);
        _revisions.remove(old);
      }
      _loaded.removeWhere((id) => !present.contains(id));
      for (final a in atlases) {
        final prefix = 'custom.${a.id}';
        final revision = jsonEncode(a.toJson());
        if (_revisions[prefix] == revision &&
            a.atlas.sprites.keys.every(
              (id) => SpriteRegistry.has('$prefix.$id'),
            )) {
          _aliases(a);
          continue;
        }
        try {
          await _register(a, prefix: prefix);
          _aliases(a);
          SpriteRegistry.trimCache();
          _loaded.add(prefix);
          _revisions[prefix] = revision;
        } catch (e) {
          problems.add('${a.name}: $e');
        }
      }
    } catch (e) {
      problems.add('Custom sprites unavailable: $e');
    }
    for (final p in problems) {
      debugPrint(p);
    }
  }
}
