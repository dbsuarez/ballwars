import 'sprite_atlas.dart';

/// Maps replacement artwork onto stable names used by saved skills/replays.
class SpriteReplacement {
  static Map<String, String?> defaults(SpriteAtlas old, SpriteAtlas next) => {
    for (final name in old.sprites.keys)
      name: next.sprites.containsKey(name)
          ? name
          : old.sprites.length == 1 && next.sprites.length == 1
          ? next.sprites.keys.single
          : null,
  };

  static SpriteAtlas apply(SpriteAtlas next, Map<String, String?> mapping) {
    final used = <String>{};
    final result = <String, SpriteDef>{};
    void add(String name, SpriteDef s) {
      if (result.containsKey(name)) {
        throw FormatException(
          'Sprite name "$name" conflicts with a preserved name. Map that sprite to its existing name or rename it in the source JSON.',
        );
      }
      result[name] = SpriteDef(
        id: name,
        label: s.label ?? (s.id != name ? s.id : null),
        frames: s.frames,
        output: s.output,
        outputHeight: s.outputHeight,
        fit: s.fit,
        anchor: s.anchor,
        displayScale: s.displayScale,
        padding: s.padding,
        stepsPerFrame: s.stepsPerFrame,
        sharedBand: s.sharedBand,
        bleedOk: s.bleedOk,
        bleedNote: s.bleedNote,
        trimCutPadding: s.trimCutPadding,
        sourceSizes: s.sourceSizes,
        sourceOffsets: s.sourceOffsets,
      );
    }

    for (final entry in mapping.entries) {
      final source = entry.value;
      if (source == null) continue;
      final sprite = next.sprites[source];
      if (sprite == null) {
        throw FormatException(
          'Choose replacement artwork for ${entry.key} again.',
        );
      }
      if (!used.add(source)) {
        throw FormatException(
          '"$source" is assigned more than once. Each existing sprite needs a different replacement.',
        );
      }
      add(entry.key, sprite);
    }
    for (final entry in next.sprites.entries) {
      if (!used.contains(entry.key)) add(entry.key, entry.value);
    }
    // An explicitly removed name must not silently be reintroduced as new art.
    for (final entry in mapping.entries) {
      if (entry.value == null && result.containsKey(entry.key)) {
        throw FormatException(
          '"${entry.key}" still exists in the new sheet. Select its replacement instead of Remove.',
        );
      }
    }
    return SpriteAtlas(
      sheet: next.sheet,
      sheetSize: next.sheetSize,
      sprites: result,
    );
  }
}
