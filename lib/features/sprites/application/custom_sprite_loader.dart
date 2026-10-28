import 'package:flutter/foundation.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../data/sprite_atlas_repository.dart';

class CustomSpriteLoader {
  CustomSpriteLoader(this.repository, {Future<Uint8List> Function(Uri)? fetch})
    : fetch = fetch ?? fetchSpriteSheet;
  final SpriteAtlasRepository repository;
  final Future<Uint8List> Function(Uri) fetch;
  final List<String> problems = [];
  static final Set<String> _loaded = {};
  Future<void> load() async {
    problems.clear();
    try {
      final atlases = await repository.list();
      final present = atlases.map((a) => 'custom.${a.id}').toSet();
      for (final old in _loaded.difference(present)) {
        SpriteRegistry.unregister(old);
      }
      _loaded.removeWhere((id) => !present.contains(id));
      for (final a in atlases) {
        try {
          if (a.atlas.sprites.isEmpty ||
              a.atlas.sprites.length > 64 ||
              a.atlas.sprites.values.fold<int>(
                    0,
                    (n, s) => n + s.frames.length,
                  ) >
                  256 ||
              a.atlas.sprites.values.any(
                (s) => s.output > 256 || s.height > 256,
              )) {
            throw const FormatException(
              'Custom atlas exceeds the sprite/frame limits.',
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
              idPrefix: 'custom.${a.id}',
              label: a.name,
            );
            _loaded.add('custom.${a.id}');
          } finally {
            image.dispose();
          }
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
