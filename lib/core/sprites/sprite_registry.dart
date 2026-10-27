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
    ByteData? pixels;
    try {
      for (final def in atlas.sprites.values) {
        if (def.frames.isEmpty) continue;
        if (def.fit == SpriteFit.trim) {
          pixels ??= await sheet.toByteData(format: ui.ImageByteFormat.rawRgba);
        }
        out[def.id] = _CutSprite(
          await _cutSprite(def, sheet, pixels),
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

  static Future<List<ui.Image>> _cutSprite(
    SpriteDef def,
    ui.Image sheet,
    ByteData? pixels,
  ) async {
    final size = def.output;
    final height = def.height;
    final pad = def.padding.toDouble();
    final inner = Rect.fromLTWH(pad, pad, size - 2 * pad, height - 2 * pad);
    var sources = def.frames;
    if (def.fit == SpriteFit.trim && pixels != null) {
      sources = [
        for (final f in sources) _visibleBounds(pixels, sheet.width, f),
      ];
    }
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
          final fitted = applyBoxFit(BoxFit.contain, source.size, inner.size);
          dest = Alignment.center.inscribe(fitted.destination, inner);
        }
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          sheet,
          source,
          dest,
          Paint()..filterQuality = FilterQuality.none,
        );
        final picture = recorder.endRecording();
        frames.add(await picture.toImage(size, height));
        picture.dispose();
      }
    } catch (_) {
      for (final f in frames) {
        f.dispose();
      }
      rethrow;
    }
    return frames;
  }

  /// The tight box around pixels with alpha >= 16 inside [frame]; the frame
  /// itself when it is fully transparent.
  static Rect _visibleBounds(ByteData bytes, int sheetWidth, Rect frame) {
    final x0 = frame.left.floor(), x1 = frame.right.ceil();
    final y0 = frame.top.floor(), y1 = frame.bottom.ceil();
    var left = x1, top = y1, right = -1, bottom = -1;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (bytes.getUint8((y * sheetWidth + x) * 4 + 3) < 16) continue;
        left = math.min(left, x);
        right = math.max(right, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left) return frame;
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
