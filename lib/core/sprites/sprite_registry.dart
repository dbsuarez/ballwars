import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'sprite_atlas.dart';

/// Loads the JSON atlas manifests listed in `assets/sprites/atlas-index.json`
/// (a list of manifest asset paths), cuts every sprite into small isolated
/// frames once, and answers lookups by sprite id. Nothing here throws at load
/// time: problems are collected in [loadProblems] and the affected manifest is
/// skipped.
class SpriteRegistry {
  SpriteRegistry._();

  static const String indexPath = 'assets/sprites/atlas-index.json';
  static const int _defaultStepsPerFrame = 4;

  static Future<void>? _loading;
  static final Map<String, _CutSprite> _sprites = {};
  static final Map<String, Set<String>> _customIds = {};
  static final Map<String, String> _owners = {};
  static final List<String> _problems = [];
  static int _generation = 0;

  static List<String> get loadProblems => List.unmodifiable(_problems);
  static List<String> get ids => List.unmodifiable(_sprites.keys);
  static bool has(String id) => _sprites.containsKey(id);
  static int frameCount(String id) => _sprites[id]?.frames.length ?? 0;
  static int stepsPerFrame(String id) =>
      _sprites[id]?.stepsPerFrame ?? _defaultStepsPerFrame;

  /// The frame at [index] (wrapped modulo the frame count), or null when the
  /// id is unknown.
  static ui.Image? frame(String id, [int index = 0]) {
    final sprite = _sprites[id];
    if (sprite == null || sprite.frames.isEmpty) return null;
    return sprite.frames[index % sprite.frames.length];
  }

  /// Loads every bundled manifest. Idempotent: later calls return the same
  /// future. Never throws.
  static Future<void> load({AssetBundle? bundle}) =>
      _loading ??= _load(bundle ?? rootBundle);

  /// Clears all state so tests can load again.
  @visibleForTesting
  static void resetForTest() {
    _loading = null;
    _generation++;
    for (final s in _sprites.values) {
      s.dispose();
    }
    _sprites.clear();
    _customIds.clear();
    _owners.clear();
    _problems.clear();
  }

  /// Cuts an already decoded [sheet] (a user upload) under ids
  /// `<idPrefix>.<sprite id>`. Registering the same prefix again replaces its
  /// sprites. [idPrefix] must start with `custom.` so bundled ids stay safe.
  static Future<void> register(
    SpriteAtlas atlas,
    ui.Image sheet, {
    required String idPrefix,
  }) async {
    if (!idPrefix.startsWith('custom.') ||
        idPrefix.length == 'custom.'.length) {
      throw ArgumentError.value(
        idPrefix,
        'idPrefix',
        'must start with "custom." and name the upload',
      );
    }
    final nameRe = RegExp(r'^[a-z0-9-]{1,40}$');
    for (final name in atlas.sprites.keys) {
      if (!nameRe.hasMatch(name)) {
        throw ArgumentError.value(
          name,
          'atlas.sprites',
          'sprite name must match ^[a-z0-9-]{1,40}\$',
        );
      }
    }
    final problems = atlas.problems(
      sheetSize: Size(sheet.width.toDouble(), sheet.height.toDouble()),
    );
    if (problems.isNotEmpty) {
      throw ArgumentError('Atlas has problems: ${problems.join('; ')}');
    }
    final mine = _customIds[idPrefix] ?? const <String>{};
    final clashes = [
      for (final id in atlas.sprites.keys)
        if (_sprites.containsKey('$idPrefix.$id') &&
            !mine.contains('$idPrefix.$id'))
          '$idPrefix.$id',
    ];
    if (clashes.isNotEmpty) {
      throw ArgumentError(
        'Sprite ids already in use by another owner: ${clashes.join(', ')}',
      );
    }
    final gen = _generation;
    final cut = await _cutAtlas(atlas, sheet);
    if (gen != _generation) {
      for (final s in cut.values) {
        s.dispose();
      }
      return;
    }
    unregister(idPrefix);
    final added = <String>{};
    cut.forEach((id, sprite) {
      final full = '$idPrefix.$id';
      _sprites[full] = sprite;
      added.add(full);
    });
    _customIds[idPrefix] = added;
  }

  /// Removes the sprites registered under [idPrefix] and frees their images.
  static void unregister(String idPrefix) {
    final old = _customIds.remove(idPrefix);
    if (old == null) return;
    for (final id in old) {
      _sprites.remove(id)?.dispose();
    }
  }

  /// Adds one bundled sprite (a single frame) that the app draws in code
  /// instead of cutting it from a sheet, such as a pixel-art icon. The whole
  /// [image] goes through the same fit as a manifest frame ([fit],
  /// [output] wide, [outputHeight] tall or square, [padding]) and is stored
  /// under [id] like a sprite from a bundled manifest: `frame(id)` returns it
  /// and a manifest that later names the same id is skipped with a load
  /// problem.
  ///
  /// The registry stores its own copy: the caller keeps ownership of [image]
  /// and may dispose it once the future completes. Throws [ArgumentError] for
  /// ids starting with `custom.` (those belong to [register]), ids already in
  /// use, and sizes or a padding the atlas rules reject; [SpriteFit.trim] and
  /// [SpriteFit.contain] keep the image's shape, [SpriteFit.fill] stretches
  /// it. Like [load], it is discarded when [resetForTest] runs meanwhile.
  static Future<void> registerDrawn(
    String id,
    ui.Image image, {
    SpriteFit fit = SpriteFit.contain,
    int output = 64,
    int? outputHeight,
    int padding = 2,
    int stepsPerFrame = _defaultStepsPerFrame,
  }) async {
    if (id.isEmpty || id.startsWith('custom.')) {
      throw ArgumentError.value(
        id,
        'id',
        'must name a bundled sprite, not a "custom." one',
      );
    }
    if (_sprites.containsKey(id) || _owners.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'is already in use');
    }
    final def = SpriteDef(
      id: id,
      frames: [
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ],
      output: output,
      outputHeight: outputHeight,
      fit: fit,
      padding: padding,
      stepsPerFrame: stepsPerFrame,
    );
    final problems = SpriteAtlas(sheet: 'drawn', sprites: {id: def}).problems(
      sheetSize: Size(image.width.toDouble(), image.height.toDouble()),
    );
    if (output <= 0 || (outputHeight != null && outputHeight <= 0)) {
      problems.add('$id output must be a positive size');
    }
    if (problems.isNotEmpty) {
      throw ArgumentError('Drawn sprite has problems: ${problems.join('; ')}');
    }
    final gen = _generation;
    final frames = await _cutSprite(def, image);
    final sprite = _CutSprite(frames, stepsPerFrame);
    if (gen != _generation) {
      sprite.dispose();
      return;
    }
    if (_sprites.containsKey(id) || _owners.containsKey(id)) {
      sprite.dispose();
      throw ArgumentError.value(id, 'id', 'is already in use');
    }
    _owners[id] = 'drawn in code';
    _sprites[id] = sprite;
  }

  static void _problem(String text) {
    _problems.add(text);
    debugPrint('SpriteRegistry: $text');
  }

  static Future<void> _load(AssetBundle bundle) async {
    final gen = _generation;
    List<dynamic> index;
    try {
      final text = await bundle.loadString(indexPath);
      if (gen != _generation) return;
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        _problem('$indexPath must be a list of manifest paths');
        return;
      }
      index = decoded;
    } catch (e) {
      _problem('Could not read $indexPath: $e');
      return;
    }
    for (final entry in index) {
      if (gen != _generation) return;
      if (entry is! String) {
        _problem('$indexPath has an entry that is not a manifest path');
        continue;
      }
      try {
        await _loadManifest(bundle, entry, gen);
      } catch (e) {
        if (gen != _generation) return;
        _problem('Manifest $entry was skipped: $e');
      }
    }
  }

  static Future<void> _loadManifest(
    AssetBundle bundle,
    String path,
    int gen,
  ) async {
    final SpriteAtlas atlas;
    try {
      final text = await bundle.loadString(path);
      if (gen != _generation) return;
      atlas = SpriteAtlas.parse(jsonDecode(text));
    } catch (e) {
      if (gen != _generation) return;
      _problem('Manifest $path is not valid: $e');
      return;
    }
    ui.Image sheet;
    try {
      final data = await bundle.load(atlas.sheet);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      try {
        sheet = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (e) {
      if (gen != _generation) return;
      _problem(
        'Sheet ${atlas.sheet} (manifest $path) could not be decoded: $e',
      );
      return;
    }
    try {
      if (gen != _generation) return;
      final problems = atlas.problems(
        sheetSize: Size(sheet.width.toDouble(), sheet.height.toDouble()),
      );
      if (problems.isNotEmpty) {
        _problem('Manifest $path has problems: ${problems.join('; ')}');
        return;
      }
      final cut = await _cutAtlas(atlas, sheet);
      if (gen != _generation) {
        for (final s in cut.values) {
          s.dispose();
        }
        return;
      }
      for (final entry in cut.entries) {
        final owner = _owners[entry.key];
        if (owner != null) {
          _problem(
            'Sprite id ${entry.key} appears in both $owner and $path; '
            'keeping the one from $owner',
          );
          entry.value.dispose();
          continue;
        }
        _owners[entry.key] = path;
        _sprites[entry.key] = entry.value;
      }
    } catch (e) {
      if (gen != _generation) return;
      _problem('Manifest $path could not be cut: $e');
    } finally {
      sheet.dispose();
    }
  }

  static Future<Map<String, _CutSprite>> _cutAtlas(
    SpriteAtlas atlas,
    ui.Image sheet,
  ) async {
    final out = <String, _CutSprite>{};
    try {
      for (final def in atlas.sprites.values) {
        if (def.frames.isEmpty) continue;
        out[def.id] = _CutSprite(
          await _cutSprite(def, sheet),
          def.stepsPerFrame,
        );
      }
    } catch (_) {
      for (final s in out.values) {
        s.dispose();
      }
      rethrow;
    }
    return out;
  }

  static Future<List<ui.Image>> _cutSprite(SpriteDef def, ui.Image sheet) async {
    final size = def.output;
    final height = def.height;
    final pad = def.padding.toDouble();
    final inner = Rect.fromLTWH(pad, pad, size - 2 * pad, height - 2 * pad);
    final sources = def.frames;
    var union = sources.first;
    for (final r in sources) {
      union = union.expandToInclude(r);
    }
    // One scale that fits both the largest frame and the whole union band.
    final sharedScale = def.sharedBand
        ? inner.width /
              math.max(
                union.height,
                sources
                    .map((r) => math.max(r.width, r.height))
                    .reduce(math.max),
              )
        : 0.0;
    final frames = <ui.Image>[];
    try {
      for (final source in sources) {
        if (def.fit == SpriteFit.trim) {
          frames.add(
            await _trimmed(
              sheet,
              source,
              size,
              height,
              def.padding,
              def.trimCutPadding,
            ),
          );
          continue;
        }
        final Rect dest;
        if (def.sharedBand) {
          // One scale for the whole sprite; each frame sits at its offset
          // inside the union band so the animation does not jump.
          final bandTop = (size - union.height * sharedScale) / 2;
          dest = Rect.fromLTWH(
            (size - source.width * sharedScale) / 2,
            bandTop + (source.top - union.top) * sharedScale,
            source.width * sharedScale,
            source.height * sharedScale,
          );
        } else if (def.fit == SpriteFit.fill) {
          dest = inner;
        } else {
          dest = _contain(source.size, inner);
        }
        frames.add(await _draw(sheet, source, dest, size, height));
      }
    } catch (_) {
      for (final f in frames) {
        f.dispose();
      }
      rethrow;
    }
    return frames;
  }

  /// Where [content] lands when contained, centered, in [box].
  static Rect _contain(Size content, Rect box) {
    final fitted = applyBoxFit(BoxFit.contain, content, box.size);
    return Alignment.center.inscribe(fitted.destination, box);
  }

  /// [source] of [image] drawn at [dest] on a fresh [width] x [height] image,
  /// nearest-neighbor.
  static Future<ui.Image> _draw(
    ui.Image image,
    Rect source,
    Rect dest,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      dest,
      Paint()..filterQuality = FilterQuality.none,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  /// Fit "trim", in two steps: [source] is contained into the
  /// [width] x [height] canvas minus [cutPadding] on each side (0: the whole
  /// canvas), the visible art (alpha >= 16) of that cut is measured, and those
  /// bounds are contained into the canvas minus [padding] on each side, on a
  /// fresh canvas. A fully transparent cut is returned as is.
  static Future<ui.Image> _trimmed(
    ui.Image image,
    Rect source,
    int width,
    int height,
    int padding,
    int cutPadding,
  ) async {
    final full = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final cut = await _draw(
      image,
      source,
      _contain(source.size, full.deflate(cutPadding.toDouble())),
      width,
      height,
    );
    try {
      final bytes = await cut.toByteData(format: ui.ImageByteFormat.rawRgba);
      final visible = bytes == null ? null : _visibleBounds(bytes, cut);
      if (visible == null) return cut;
      final inner = full.deflate(padding.toDouble());
      final fitted = await _draw(
        cut,
        visible,
        _contain(visible.size, inner),
        width,
        height,
      );
      cut.dispose();
      return fitted;
    } catch (_) {
      cut.dispose();
      rethrow;
    }
  }

  /// The tight box around pixels with alpha >= 16 in [image] ([bytes] is its
  /// raw RGBA); null when it is fully transparent.
  static Rect? _visibleBounds(ByteData bytes, ui.Image image) {
    final w = image.width, h = image.height;
    var left = w, top = h, right = -1, bottom = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (bytes.getUint8((y * w + x) * 4 + 3) < 16) continue;
        left = math.min(left, x);
        right = math.max(right, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left) return null;
    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right + 1.0,
      bottom + 1.0,
    );
  }
}

class _CutSprite {
  final List<ui.Image> frames;
  final int stepsPerFrame;
  _CutSprite(this.frames, this.stepsPerFrame);

  void dispose() {
    for (final f in frames) {
      f.dispose();
    }
  }
}
