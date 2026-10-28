import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'sprite_atlas.dart';

/// Import metadata only. The supplied sheet is never modified.
class SpriteImport {
  static String name(String value) {
    final clean = value
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return (clean.isEmpty ? 'sprite' : clean).substring(
      0,
      math.min(clean.isEmpty ? 6 : clean.length, 40),
    );
  }

  static SpriteAtlas grid({
    required String sheet,
    required int width,
    required int height,
    int columns = 1,
    int rows = 1,
    bool animation = true,
    String spriteName = 'sprite',
    int stepsPerFrame = 4,
    int inset = 0,
  }) {
    if (columns < 1 ||
        rows < 1 ||
        columns * rows > 256 ||
        width % columns != 0 ||
        height % rows != 0) {
      throw const FormatException(
        'Use 1 to 256 equal cells that divide the sheet exactly.',
      );
    }
    final w = width ~/ columns, h = height ~/ rows;
    if (inset < 0 || inset * 2 >= math.min(w, h)) {
      throw const FormatException('Inset leaves no room for artwork.');
    }
    final frames = [
      for (var y = 0; y < rows; y++)
        for (var x = 0; x < columns; x++)
          Rect.fromLTWH(
            (x * w + inset).toDouble(),
            (y * h + inset).toDouble(),
            (w - inset * 2).toDouble(),
            (h - inset * 2).toDouble(),
          ),
    ];
    final n = name(spriteName);
    final sprites = animation
        ? {
            n: SpriteDef(
              id: n,
              frames: frames,
              output: 128,
              stepsPerFrame: stepsPerFrame,
            ),
          }
        : {
            for (var i = 0; i < frames.length; i++)
              '$n-${i + 1}': SpriteDef(
                id: '$n-${i + 1}',
                frames: [frames[i]],
                output: 128,
              ),
          };
    if (sprites.length > 64) {
      throw const FormatException('At most 64 separate sprites per upload.');
    }
    return SpriteAtlas(
      sheet: sheet,
      sheetSize: Size(width.toDouble(), height.toDouble()),
      sprites: sprites,
    );
  }

  static SpriteAtlas metadata(
    Map<String, dynamic> json, {
    required String sheet,
  }) {
    final raw = json['frames'];
    final entries = raw is Map
        ? raw.entries
              .map(
                (e) => MapEntry(
                  e.key.toString(),
                  Map<String, dynamic>.from(e.value as Map),
                ),
              )
              .toList()
        : raw is List
        ? [
            for (var i = 0; i < raw.length; i++)
              MapEntry(
                (raw[i] as Map)['filename']?.toString() ?? 'sprite_$i',
                Map<String, dynamic>.from(raw[i] as Map),
              ),
          ]
        : throw const FormatException('JSON needs a frames array or object.');
    if (entries.isEmpty || entries.length > 256) {
      throw const FormatException('Use 1 to 256 frames.');
    }
    Rect rect(Map r) => Rect.fromLTWH(
      (r['x'] as num).toDouble(),
      (r['y'] as num).toDouble(),
      (r['w'] as num).toDouble(),
      (r['h'] as num).toDouble(),
    );
    for (final e in entries) {
      if (e.value['rotated'] == true) {
        throw const FormatException(
          'Rotated frames are unsupported. Export without rotation.',
        );
      }
    }
    final groups = <String, List<int>>{};
    final meta = json['meta'] as Map?;
    final tags = meta?['frameTags'] as List?;
    if (tags != null && tags.isNotEmpty) {
      for (final t in tags) {
        final from = t['from'] as int, to = t['to'] as int;
        if (from < 0 || to < from || to >= entries.length) {
          throw const FormatException(
            'Animation tag is outside the frame range.',
          );
        }
        final indices = [for (var i = from; i <= to; i++) i];
        final direction = t['direction'] ?? 'forward';
        final tagName = name(t['name'] as String);
        if (groups.containsKey(tagName)) {
          throw const FormatException(
            'Animation names must remain unique after removing spaces and punctuation.',
          );
        }
        groups[tagName] = switch (direction) {
          'reverse' => indices.reversed.toList(),
          'pingpong' => [
            ...indices,
            ...indices
                .skip(1)
                .take(math.max(0, indices.length - 2))
                .toList()
                .reversed,
          ],
          'forward' => indices,
          _ => throw const FormatException(
            'Unsupported animation direction. Export forward, reverse or pingpong.',
          ),
        };
      }
    } else if (meta?['app']?.toString().toLowerCase().contains('aseprite') ==
            true ||
        raw is List) {
      groups['sprite'] = [for (var i = 0; i < entries.length; i++) i];
    } else {
      for (var i = 0; i < entries.length; i++) {
        final stem = entries[i].key
            .replaceFirst(RegExp(r'\.[^.]+$'), '')
            .replaceFirst(RegExp(r'[_ -]?\d+$'), '');
        groups.putIfAbsent(name(stem), () => []).add(i);
      }
    }
    if (groups.length > 64) {
      throw const FormatException('At most 64 sprites per upload.');
    }
    final sprites = <String, SpriteDef>{};
    for (final g in groups.entries) {
      final values = g.value.map((i) => entries[i].value).toList();
      final duration =
          values.fold<double>(
            0,
            (v, f) => v + ((f['duration'] as num?) ?? 100),
          ) /
          values.length;
      sprites[g.key] = SpriteDef(
        id: g.key,
        output: 128,
        frames: [for (final f in values) rect(f['frame'] as Map)],
        sourceSizes: [
          for (final f in values)
            f['sourceSize'] is Map
                ? Size(
                    (f['sourceSize']['w'] as num).toDouble(),
                    (f['sourceSize']['h'] as num).toDouble(),
                  )
                : rect(f['frame'] as Map).size,
        ],
        sourceOffsets: [
          for (final f in values)
            f['spriteSourceSize'] is Map
                ? Offset(
                    (f['spriteSourceSize']['x'] as num).toDouble(),
                    (f['spriteSourceSize']['y'] as num).toDouble(),
                  )
                : Offset.zero,
        ],
        stepsPerFrame: (duration * 60 / 1000).round().clamp(1, 3600),
      );
    }
    final size = meta?['size'] as Map?;
    return SpriteAtlas(
      sheet: sheet,
      sprites: sprites,
      sheetSize: size == null
          ? null
          : Size((size['w'] as num).toDouble(), (size['h'] as num).toDouble()),
    );
  }

  /// Reports art touching cell boundaries; inset/transparent gutters isolate it.
  static List<Rect> trimToCleanEdges(
    Uint8List rgba,
    int width,
    int height,
    List<Rect> frames,
  ) {
    bool solid(int x, int y) => rgba[(y * width + x) * 4 + 3] >= 24;
    return [
      for (final f in frames)
        (() {
          var l = f.left.toInt(),
              t = f.top.toInt(),
              r = f.right.toInt(),
              b = f.bottom.toInt();
          bool column(int x) {
            for (var y = t; y < b; y++) {
              if (solid(x, y)) return true;
            }
            return false;
          }

          bool row(int y) {
            for (var x = l; x < r; x++) {
              if (solid(x, y)) return true;
            }
            return false;
          }

          final horizontal = math.min(40, (r - l) ~/ 3),
              vertical = math.min(40, (b - t) ~/ 3);
          if (l > 0 && column(l)) {
            for (var d = 1; d <= horizontal; d++) {
              if (!column(l + d)) {
                l += d;
                break;
              }
            }
          }
          if (r < width && column(r - 1)) {
            for (var d = 1; d <= horizontal; d++) {
              if (!column(r - 1 - d)) {
                r -= d;
                break;
              }
            }
          }
          if (t > 0 && row(t)) {
            for (var d = 1; d <= vertical; d++) {
              if (!row(t + d)) {
                t += d;
                break;
              }
            }
          }
          if (b < height && row(b - 1)) {
            for (var d = 1; d <= vertical; d++) {
              if (!row(b - 1 - d)) {
                b -= d;
                break;
              }
            }
          }
          return Rect.fromLTRB(
            l.toDouble(),
            t.toDouble(),
            r.toDouble(),
            b.toDouble(),
          );
        })(),
    ];
  }

  /// Reports art touching cell boundaries; inset/transparent gutters isolate it.
  static List<String> edgeProblems(
    SpriteAtlas atlas,
    Uint8List rgba,
    int width,
    int height,
  ) {
    final problems = <String>[];
    bool opaque(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < width &&
        y < height &&
        rgba[(y * width + x) * 4 + 3] >= 24;
    for (final s in atlas.sprites.values) {
      for (var i = 0; i < s.frames.length; i++) {
        final f = s.frames[i];
        final touched = <String>{};
        for (var x = f.left.toInt(); x < f.right; x++) {
          if (f.top > 0 && opaque(x, f.top.toInt())) touched.add('top');
          if (f.bottom < height && opaque(x, f.bottom.toInt() - 1)) {
            touched.add('bottom');
          }
        }
        for (var y = f.top.toInt(); y < f.bottom; y++) {
          if (f.left > 0 && opaque(f.left.toInt(), y)) touched.add('left');
          if (f.right < width && opaque(f.right.toInt() - 1, y)) {
            touched.add('right');
          }
        }
        if (touched.isNotEmpty && !s.bleedOk) {
          problems.add(
            '${s.id} frame ${i + 1} has visible pixels on its ${touched.join(" / ")} cell edge. This can be intentional.',
          );
        }
      }
    }
    return problems;
  }
}

Map<String, dynamic> spriteAtlasJson(SpriteAtlas atlas) => {
  'sheet': atlas.sheet,
  if (atlas.sheetSize != null)
    'sheetSize': [
      atlas.sheetSize!.width.toInt(),
      atlas.sheetSize!.height.toInt(),
    ],
  'sprites': {
    for (final s in atlas.sprites.values)
      s.id: {
        'frames': [
          for (final r in s.frames) [r.left, r.top, r.width, r.height],
        ],
        'output': s.output,
        if (s.label != null) 'label': s.label,
        if (s.outputHeight != null) 'outputHeight': s.outputHeight,
        'anchor': [s.anchor.dx, s.anchor.dy],
        if (s.displayScale != 1) 'displayScale': s.displayScale,
        if (s.opacity != 1) 'opacity': s.opacity,
        'fit': s.fit.name,
        'padding': s.padding,
        'stepsPerFrame': s.stepsPerFrame,
        if (s.sharedBand) 'sharedBand': true,
        if (s.bleedOk) 'bleedOk': true,
        if (s.bleedNote != null) 'bleedNote': s.bleedNote,
        if (s.trimCutPadding != 0) 'trimCutPadding': s.trimCutPadding,
        if (s.sourceSizes != null)
          'sourceSizes': [
            for (final z in s.sourceSizes!) [z.width, z.height],
          ],
        if (s.sourceOffsets != null)
          'sourceOffsets': [
            for (final o in s.sourceOffsets!) [o.dx, o.dy],
          ],
      },
  },
};
