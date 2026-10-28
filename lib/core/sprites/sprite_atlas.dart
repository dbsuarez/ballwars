import 'dart:ui';

/// How a cut frame is scaled into its output image: [contain] keeps the
/// frame's proportions inside the output minus its padding; [trim] contains
/// the frame into the whole output (no padding), measures the visible art
/// (alpha >= 16) of that cut and contains those bounds into the output minus
/// its padding, so the art fills the box whatever margin the sheet cell has
/// (a fully transparent frame stays the plain cut; not with sharedBand);
/// [fill] stretches the frame to the whole output box (for strips such as the
/// sticky goo rim).
enum SpriteFit { contain, trim, fill }

/// One sprite: its frames on the sheet and how to cut and play them.
class SpriteDef {
  final String id;
  final String? label;

  /// Frame rectangles in sheet pixels.
  final List<Rect> frames;

  /// Original canvas geometry for trimmed editor exports, one entry per frame.
  final List<Size>? sourceSizes;
  final List<Offset>? sourceOffsets;

  /// The point of the output image (0..1 on each axis, from its top left)
  /// that painters place on their target point. Defaults to the center.
  final Offset anchor;

  /// Visual multiplier around the anchor; does not change collision geometry.
  final double displayScale;

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

  /// Fit [SpriteFit.trim] only: the margin of its first cut, the one whose
  /// visible art is measured. 0 (the default) cuts into the whole output.
  final int trimCutPadding;

  const SpriteDef({
    required this.id,
    this.label,
    required this.frames,
    this.sourceSizes,
    this.sourceOffsets,
    this.anchor = const Offset(0.5, 0.5),
    this.displayScale = 1,
    required this.output,
    this.outputHeight,
    this.fit = SpriteFit.contain,
    this.sharedBand = false,
    this.stepsPerFrame = 4,
    this.bleedOk = false,
    this.bleedNote,
    this.padding = 2,
    this.trimCutPadding = 0,
  });

  /// Height of the output image in pixels.
  int get height => outputHeight ?? output;
}

/// A sprite sheet and the sprites cut from it, read from a JSON manifest.
class SpriteAtlas {
  final String sheet;
  final Map<String, SpriteDef> sprites;

  /// The sheet's size in pixels as the manifest expects it (`sheetSize`), or
  /// null when the manifest does not say. [problems] reports a mismatch.
  final Size? sheetSize;

  const SpriteAtlas({
    required this.sheet,
    required this.sprites,
    this.sheetSize,
  });

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
    Size? sheetSize;
    final sizeRaw = json['sheetSize'];
    if (sizeRaw != null) {
      if (sizeRaw is! List ||
          sizeRaw.length != 2 ||
          sizeRaw.any((n) => n is! int || n <= 0)) {
        throw const FormatException(
          'Atlas manifest "sheetSize" must be [width, height] in whole pixels',
        );
      }
      sheetSize = Size(
        (sizeRaw[0] as int).toDouble(),
        (sizeRaw[1] as int).toDouble(),
      );
    }
    final sprites = <String, SpriteDef>{};
    raw.forEach((id, value) {
      sprites[id as String] = _parseSprite(id, value);
    });
    return SpriteAtlas(sheet: sheet, sprites: sprites, sheetSize: sheetSize);
  }

  static SpriteDef _parseSprite(String id, Object? v) {
    if (v is! Map) throw FormatException('Sprite $id must be an object');
    if (v['label'] != null &&
        (v['label'] is! String ||
            (v['label'] as String).trim().isEmpty ||
            (v['label'] as String).length > 80)) {
      throw FormatException('Sprite $id label must contain 1 to 80 characters');
    }
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
    final scale = v['displayScale'] ?? 1;
    if (scale is! num || !scale.isFinite || scale < .5 || scale > 2) {
      throw FormatException(
        'Sprite $id displayScale must be between 0.5 and 2',
      );
    }
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
    final cutPadding = v['trimCutPadding'] ?? 0;
    if (cutPadding is! int || cutPadding < 0) {
      throw FormatException(
        'Sprite $id trimCutPadding must be a whole number of pixels, 0 or more',
      );
    }
    return SpriteDef(
      id: id,
      label: v['label'] is String ? v['label'] as String : null,
      padding: padding,
      trimCutPadding: cutPadding,
      frames: frames,
      sourceSizes: v['sourceSizes'] == null
          ? null
          : [
              for (final s in v['sourceSizes'] as List)
                Size((s[0] as num).toDouble(), (s[1] as num).toDouble()),
            ],
      sourceOffsets: v['sourceOffsets'] == null
          ? null
          : [
              for (final s in v['sourceOffsets'] as List)
                Offset((s[0] as num).toDouble(), (s[1] as num).toDouble()),
            ],
      anchor: anchor,
      displayScale: scale.toDouble(),
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
    final expected = this.sheetSize;
    if (expected != null && expected != sheetSize) {
      out.add(
        '$sheet is $sheetText, the manifest expects '
        '${expected.width.round()}x${expected.height.round()}',
      );
    }
    for (final def in sprites.values) {
      if (!def.displayScale.isFinite ||
          def.displayScale < .5 ||
          def.displayScale > 2) {
        out.add('${def.id} displayScale must be between 0.5 and 2');
      }
      if (def.sourceSizes != null || def.sourceOffsets != null) {
        if (def.sourceSizes?.length != def.frames.length ||
            def.sourceOffsets?.length != def.frames.length) {
          out.add('${def.id} trimmed geometry must match its frame count');
        } else {
          for (var i = 0; i < def.frames.length; i++) {
            final size = def.sourceSizes![i],
                offset = def.sourceOffsets![i],
                f = def.frames[i];
            if (!size.width.isFinite ||
                !size.height.isFinite ||
                size.width <= 0 ||
                size.height <= 0 ||
                offset.dx < 0 ||
                offset.dy < 0 ||
                !offset.dx.isFinite ||
                !offset.dy.isFinite ||
                offset.dx + f.width > size.width ||
                offset.dy + f.height > size.height) {
              out.add('${def.id} frame ${i + 1} has invalid trimmed geometry');
            }
          }
        }
      }
      if (def.frames.isEmpty) out.add('${def.id} has no frames');
      for (var i = 0; i < def.frames.length; i++) {
        final f = def.frames[i];
        if (!f.left.isFinite ||
            !f.top.isFinite ||
            !f.width.isFinite ||
            !f.height.isFinite ||
            f.width <= 0 ||
            f.height <= 0) {
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
          if (def.frames[i] != def.frames[j] &&
              def.frames[i].overlaps(def.frames[j])) {
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
      if (def.fit == SpriteFit.fill && def.sharedBand) {
        out.add('${def.id} fill cannot be combined with sharedBand');
      }
      if (def.fit == SpriteFit.trim && def.sharedBand) {
        out.add('${def.id} trim cannot be combined with sharedBand');
      }
      if (def.trimCutPadding != 0 && def.fit != SpriteFit.trim) {
        out.add('${def.id} sets trimCutPadding but its fit is not trim');
      }
      if (def.trimCutPadding * 2 >= def.output ||
          def.trimCutPadding * 2 >= def.height) {
        out.add(
          '${def.id} trimCutPadding ${def.trimCutPadding} leaves no room in a '
          '${def.output}x${def.height} px output',
        );
      }
      final a = def.anchor;
      if (!(a.dx >= 0 && a.dx <= 1 && a.dy >= 0 && a.dy <= 1)) {
        out.add(
          '${def.id} anchor [${a.dx}, ${a.dy}] must be 0 to 1 on each axis',
        );
      }
      if (def.bleedOk && (def.bleedNote == null || def.bleedNote!.isEmpty)) {
        out.add('${def.id} sets bleedOk but has no bleedNote explaining why');
      }
    }
    return out;
  }
}
