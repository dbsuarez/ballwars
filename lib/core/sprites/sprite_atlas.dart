import 'dart:ui';

/// How a cut frame is scaled into its output image: [contain] keeps the
/// frame's proportions, [trim] first shrinks the frame to its visible art
/// (alpha >= 16) and then contains it, [fill] stretches the frame to the
/// whole output box (for strips such as the sticky goo rim).
enum SpriteFit { contain, trim, fill }

/// One sprite: its frames on the sheet and how to cut and play them.
class SpriteDef {
  final String id;

  /// Frame rectangles in sheet pixels.
  final List<Rect> frames;

  /// Anchor inside the output image, 0..1 on each axis.
  final Offset anchor;

  /// Width of the output image in pixels (its side when square).
  final int output;

  /// Height of the output image when it is not square; null means [output].
  final int? outputHeight;
  final SpriteFit fit;

  /// True when all frames share one scale and baseline.
  final bool sharedBand;

  /// Simulation steps each frame is shown for.
  final int stepsPerFrame;

  /// True when frames may touch neighbouring art on the sheet.
  final bool bleedOk;

  /// Why bleeding is fine; required when [bleedOk] is true.
  final String? bleedNote;

  /// Transparent margin in pixels kept on each side of the output image.
  final int padding;

  const SpriteDef({
    required this.id,
    required this.frames,
    this.anchor = const Offset(0.5, 0.5),
    required this.output,
    this.outputHeight,
    this.fit = SpriteFit.contain,
    this.sharedBand = false,
    this.stepsPerFrame = 4,
    this.bleedOk = false,
    this.bleedNote,
    this.padding = 2,
  });

  /// Height of the output image in pixels.
  int get height => outputHeight ?? output;
}

/// A sprite sheet and the sprites cut from it, read from a JSON manifest.
class SpriteAtlas {
  final String sheet;
  final Map<String, SpriteDef> sprites;

  const SpriteAtlas({required this.sheet, required this.sprites});

  /// Reads a decoded JSON manifest. Throws [FormatException] for malformed
  /// input; messages name the sprite id.
  static SpriteAtlas parse(Object? json) {
    if (json is! Map) {
      throw const FormatException('Atlas manifest must be a JSON object');
    }
    final sheet = json['sheet'];
    if (sheet is! String || sheet.isEmpty) {
      throw const FormatException('Atlas manifest needs a "sheet" path');
    }
    final raw = json['sprites'];
    if (raw is! Map) {
      throw const FormatException('Atlas manifest needs a "sprites" object');
    }
    final sprites = <String, SpriteDef>{};
    raw.forEach((id, value) {
      sprites[id as String] = _parseSprite(id, value);
    });
    return SpriteAtlas(sheet: sheet, sprites: sprites);
  }

  static SpriteDef _parseSprite(String id, Object? v) {
    if (v is! Map) throw FormatException('Sprite $id must be an object');
    final framesRaw = v['frames'];
    if (framesRaw is! List) {
      throw FormatException('Sprite $id needs a "frames" list');
    }
    final frames = <Rect>[];
    for (var i = 0; i < framesRaw.length; i++) {
      final r = framesRaw[i];
      if (r is! List || r.length != 4 || r.any((n) => n is! num)) {
        throw FormatException(
          'Sprite $id frame ${i + 1} must be [x, y, width, height]',
        );
      }
      frames.add(
        Rect.fromLTWH(
          r[0].toDouble(),
          r[1].toDouble(),
          r[2].toDouble(),
          r[3].toDouble(),
        ),
      );
    }
    final output = v['output'];
    if (output is! int || output <= 0) {
      throw FormatException('Sprite $id needs a positive integer "output"');
    }
    final outputHeight = v['outputHeight'];
    if (outputHeight != null && (outputHeight is! int || outputHeight <= 0)) {
      throw FormatException(
        'Sprite $id outputHeight must be a positive integer',
      );
    }
    var anchor = const Offset(0.5, 0.5);
    final a = v['anchor'];
    if (a != null) {
      if (a is! List || a.length != 2 || a.any((n) => n is! num)) {
        throw FormatException('Sprite $id anchor must be [x, y]');
      }
      anchor = Offset(a[0].toDouble(), a[1].toDouble());
    }
    final fitRaw = v['fit'] ?? 'contain';
    final fit = switch (fitRaw) {
      'contain' => SpriteFit.contain,
      'trim' => SpriteFit.trim,
      'fill' => SpriteFit.fill,
      _ => throw FormatException(
        'Sprite $id fit must be "contain", "trim" or "fill", got $fitRaw',
      ),
    };
    final steps = v['stepsPerFrame'] ?? 4;
    if (steps is! int || steps <= 0) {
      throw FormatException(
        'Sprite $id stepsPerFrame must be a positive integer',
      );
    }
    final shared = v['sharedBand'] ?? false;
    final bleed = v['bleedOk'] ?? false;
    final note = v['bleedNote'];
    if (shared is! bool ||
        bleed is! bool ||
        (note != null && note is! String)) {
      throw FormatException(
        'Sprite $id sharedBand and bleedOk must be true/false, bleedNote text',
      );
    }
    final padding = v['padding'] ?? 2;
    if (padding is! int || padding < 0) {
      throw FormatException(
        'Sprite $id padding must be a whole number of pixels, 0 or more',
      );
    }
    return SpriteDef(
      id: id,
      padding: padding,
      frames: frames,
      anchor: anchor,
      output: output,
      outputHeight: outputHeight as int?,
      fit: fit,
      sharedBand: shared,
      stepsPerFrame: steps,
      bleedOk: bleed,
      bleedNote: note as String?,
    );
  }

  /// Plain-language problems with this atlas against a sheet of [sheetSize].
  /// Frames are numbered from 1 in the messages. Empty means valid.
  List<String> problems({required Size sheetSize}) {
    final out = <String>[];
    final sheetText = '${sheetSize.width.round()}x${sheetSize.height.round()}';
    for (final def in sprites.values) {
      if (def.frames.isEmpty) out.add('${def.id} has no frames');
      for (var i = 0; i < def.frames.length; i++) {
        final f = def.frames[i];
        if (f.width <= 0 || f.height <= 0) {
          out.add('${def.id} frame ${i + 1} has no area');
        } else if (f.left < 0 ||
            f.top < 0 ||
            f.right > sheetSize.width ||
            f.bottom > sheetSize.height) {
          out.add('${def.id} frame ${i + 1} is outside the sheet ($sheetText)');
        }
      }
      for (var i = 0; i < def.frames.length; i++) {
        for (var j = i + 1; j < def.frames.length; j++) {
          if (def.frames[i].overlaps(def.frames[j])) {
            out.add('${def.id} frames ${i + 1} and ${j + 1} overlap');
          }
        }
      }
      if (def.padding * 2 >= def.output || def.padding * 2 >= def.height) {
        out.add(
          '${def.id} padding ${def.padding} leaves no room in a '
          '${def.output}x${def.height} px output',
        );
      }
      if (def.sharedBand && def.height != def.output) {
        out.add('${def.id} sharedBand needs a square output');
      }
      if (def.bleedOk && (def.bleedNote == null || def.bleedNote!.isEmpty)) {
        out.add('${def.id} sets bleedOk but has no bleedNote explaining why');
      }
    }
    return out;
  }
}
