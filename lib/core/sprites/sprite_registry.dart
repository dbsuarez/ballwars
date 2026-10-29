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

  /// The default anchor: the center of the image.
  static const Offset center = Offset(0.5, 0.5);

  static Future<void>? _loading;
  static final Map<String, _CutSprite> _sprites = {};
  static Map<String, String> _scope = const {};
  static T withArtwork<T>(
    Map<String, String> replacements,
    T Function() paint,
  ) {
    final previous = _scope;
    _scope = replacements;
    try {
      return paint();
    } finally {
      _scope = previous;
    }
  }

  static String _id(String id) => _scope[id] ?? id;
  static Future<Map<String, Object>> embedDrawn(
    Map<String, String> replacements,
  ) async {
    final result = <String, Object>{};
    var total = 0;
    for (final e in replacements.entries) {
      if (_owners[e.key] != 'drawn in code') continue;
      final cached = _encodedDrawn[e.key];
      if (cached != null) {
        total += ((cached['png'] as String).length * 3) ~/ 4;
        if (total > 262144) {
          throw const FormatException('Too much generated replay artwork.');
        }
        result[e.value] = cached;
        continue;
      }
      final cut = _sprites[e.value];
      if (cut == null || cut.frames.length != 1) continue;
      final image = cut.frames.single;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null ||
          png.lengthInBytes > 65536 ||
          image.width > 256 ||
          image.height > 256) {
        throw const FormatException(
          'Generated replay artwork exceeds portable limits.',
        );
      }
      total += png.lengthInBytes;
      if (total > 262144) {
        throw const FormatException('Too much generated replay artwork.');
      }
      final encoded = <String, Object>{
        'png': base64Encode(png.buffer.asUint8List()),
        'anchor': [cut.anchor.dx, cut.anchor.dy],
        'scale': imageScale(image),
        'opacity': imageOpacity(image),
        'steps': cut.stepsPerFrame,
      };
      _encodedDrawn[e.key] = encoded;
      result[e.value] = encoded;
    }
    return result;
  }

  static Future<void> restoreEmbedded(Map<String, Object> entries) async {
    if (entries.length > 128) {
      throw const FormatException('Too many embedded sprites.');
    }
    var total = 0;
    for (final e in entries.entries) {
      if (!RegExp(r'^built\.[a-f0-9]{40}\.').hasMatch(e.key) ||
          e.value is! Map) {
        throw const FormatException('Invalid embedded sprite.');
      }
      if (_sprites.containsKey(e.key)) continue;
      final j = e.value as Map,
          bytes = base64Decode((e.value as Map)['png'] as String);
      total += bytes.length;
      if (bytes.length < 24 ||
          bytes.length > 65536 ||
          total > 262144 ||
          bytes[0] != 137 ||
          bytes[1] != 80 ||
          bytes[2] != 78 ||
          bytes[3] != 71) {
        throw const FormatException('Invalid embedded PNG.');
      }
      final data = ByteData.sublistView(bytes);
      if (data.getUint32(16) > 256 || data.getUint32(20) > 256) {
        throw const FormatException('Embedded dimensions exceed 256 pixels.');
      }
      final raw = j['anchor'];
      if (raw is! List ||
          raw.length != 2 ||
          raw.any((v) => v is! num || !v.isFinite || v < 0 || v > 1)) {
        throw const FormatException('Invalid embedded anchor.');
      }
      final scale = j['scale'], opacity = j['opacity'], steps = j['steps'];
      if (scale is! num ||
          !scale.isFinite ||
          scale < .5 ||
          scale > 2 ||
          opacity is! num ||
          !opacity.isFinite ||
          opacity < 0 ||
          opacity > 1 ||
          steps is! int ||
          steps < 1 ||
          steps > 600) {
        throw const FormatException('Invalid embedded playback settings.');
      }
      final gen = _generation, codec = await ui.instantiateImageCodec(bytes);
      try {
        final image = (await codec.getNextFrame()).image;
        if (gen != _generation) {
          image.dispose();
          continue;
        }
        _imageScales[image] = scale.toDouble();
        _imageOpacity[image] = opacity.toDouble();
        final cut = _CutSprite(
          [image],
          steps,
          Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble()),
        );
        _sprites[e.key] = cut;
        (_customIds[e.key.substring(0, 46)] ??= {}).add(e.key);
        _catalog[e.key] = (1, steps, cut.anchor);
      } finally {
        codec.dispose();
      }
    }
  }

  static const assetRevision = String.fromEnvironment('ASSET_REVISION');
  static final Map<String, String> frozenIds = {};
  static final Map<String, Map<String, Object>> _encodedDrawn = {};
  static final Map<String, (int, int, Offset)> _catalog = {};
  static final Map<String, Set<String>> _evicted = {};
  static final Map<String, int> _pins = {};
  static int cacheBudgetBytes = 128 * 1024 * 1024;
  static int _clock = 0;
  static int get decodedBytes => _sprites.values.toSet().fold(
    0,
    (n, s) => n + s.frames.fold<int>(0, (n, f) => n + f.width * f.height * 4),
  );
  static int get pinnedBytes {
    final held = {
      ..._pins.keys,
      for (final group in _customIds.values)
        if (group.any((id) => (_pins[id] ?? 0) > 0)) ...group,
    };
    return held
        .map((id) => _sprites[id])
        .whereType<_CutSprite>()
        .toSet()
        .fold(
          0,
          (n, s) =>
              n + s.frames.fold<int>(0, (n, f) => n + f.width * f.height * 4),
        );
  }

  static VoidCallback pin(Iterable<String> ids) {
    final held = ids.toSet();
    for (final id in held) {
      _pins[id] = (_pins[id] ?? 0) + 1;
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      for (final id in held) {
        final n = (_pins[id] ?? 1) - 1;
        if (n == 0) {
          _pins.remove(id);
        } else {
          _pins[id] = n;
        }
      }
      trimCache();
    };
  }

  /// Aliases share decoded frames; replacing a live upload cannot mutate a
  /// pinned historical revision. Every owner releases its own reference.
  static void alias(String source, String target, String group) {
    if (_sprites.containsKey(target)) return;
    final sprite = _sprites[source];
    if (sprite == null) return;
    sprite.references++;
    _sprites[target] = sprite;
    (_customIds[group] ??= {}).add(target);
    _catalog[target] = (
      sprite.frames.length,
      sprite.stepsPerFrame,
      sprite.anchor,
    );
    _collectionLabels[target] = displayLabel(source);
  }

  static void trimCache() {
    final groups = _customIds.keys.toList()
      ..sort((a, b) {
        int age(String key) => _customIds[key]!
            .map((id) => _sprites[_id(id)]?.lastUsed ?? 0)
            .fold(0, math.max);
        return age(a).compareTo(age(b));
      });
    for (final prefix in groups) {
      if (decodedBytes <= cacheBudgetBytes) break;
      final ids = _customIds[prefix]!;
      if (ids.any((id) => (_pins[id] ?? 0) > 0)) continue;
      _evicted[prefix] = {...ids};
      for (final id in ids) {
        _sprites.remove(id)?.dispose();
      }
      _customIds.remove(prefix);
    }
  }

  /// Used only for trusted, commit-pinned bundled manifests.
  static Future<void> registerHistorical(
    SpriteAtlas atlas,
    ui.Image sheet,
    String commit,
  ) async {
    final issues = atlas.problems(
      sheetSize: Size(sheet.width.toDouble(), sheet.height.toDouble()),
    );
    if (issues.isNotEmpty) throw FormatException(issues.join('\n'));
    final gen = _generation;
    if (atlas.sprites.values.fold<int>(
          0,
          (n, s) => n + s.output * s.height * s.frames.length * 4,
        ) >
        67108864) {
      throw const FormatException('Historical atlas exceeds 64 MB decoded.');
    }
    final cut = await _cutAtlas(atlas, sheet);
    if (gen != _generation) {
      for (final e in cut.values) {
        e.dispose();
      }
      return;
    }
    for (final e in cut.entries) {
      final id = 'built.$commit.${e.key}';
      if (_sprites.containsKey(id)) {
        e.value.dispose();
        continue;
      }
      _sprites[_id(id)] = e.value;
      (_customIds['built.$commit'] ??= {}).add(id);
      _catalog[id] = (
        e.value.frames.length,
        e.value.stepsPerFrame,
        e.value.anchor,
      );
    }
    revision.value++;
  }

  static final Expando<double> _imageScales = Expando('sprite display scale');
  static final Expando<double> _imageOpacity = Expando('sprite opacity');
  static double imageOpacity(ui.Image image) => _imageOpacity[image] ?? 1;
  static final Paint _opaqueImagePaint = Paint()
    ..filterQuality = FilterQuality.none;
  static Paint imagePaint(ui.Image image, {double opacity = 1}) {
    final alpha = (opacity * imageOpacity(image)).clamp(0.0, 1.0);
    if (alpha == 1) return _opaqueImagePaint;
    return Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(
        const Color(0xffffffff).withValues(alpha: alpha),
        BlendMode.modulate,
      );
  }

  static double imageScale(ui.Image image) => _imageScales[image] ?? 1;

  /// Apply saved artwork scale without resizing pixels or moving its anchor.
  static Rect imageRect(
    ui.Image image,
    Offset target,
    double width,
    double height,
    Offset anchor,
  ) => placeRect(
    target,
    width * imageScale(image),
    height * imageScale(image),
    anchor,
  );
  static final Map<String, Set<String>> _customIds = {};
  static final Map<String, String> _collectionLabels = {};
  static final Map<String, String> _spriteLabels = {};
  static String spriteLabel(String id) =>
      _spriteLabels[id] ?? id.split('.').last;
  static String? collectionLabel(String id) => _collectionLabels[id];
  static String displayLabel(String id) {
    final label = collectionLabel(id), name = spriteLabel(id);
    return label == null ? name : '$label / ${name.replaceAll('-', ' ')}';
  }

  static final Map<String, String> _owners = {};
  static final List<String> _problems = [];
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static int _generation = 0;

  static List<String> get loadProblems => List.unmodifiable(_problems);
  static List<String> get ids => List.unmodifiable(
    {
      ..._sprites.keys,
      ..._catalog.keys,
    }.where((id) => !id.startsWith('built.') && !id.contains('~')),
  );
  static bool has(String id) => _sprites.containsKey(_id(id));
  static int frameCount(String id) =>
      _sprites[_id(id)]?.frames.length ?? _catalog[_id(id)]?.$1 ?? 0;
  static int stepsPerFrame(String id) =>
      _sprites[_id(id)]?.stepsPerFrame ??
      _catalog[_id(id)]?.$2 ??
      _defaultStepsPerFrame;

  /// The frame at [index] (wrapped modulo the frame count), or null when the
  /// id is unknown.
  static ui.Image? frame(String id, [int index = 0]) {
    final sprite = _sprites[_id(id)];
    if (sprite == null || sprite.frames.isEmpty) return null;
    sprite.lastUsed = ++_clock;
    return sprite.frames[index % sprite.frames.length];
  }

  /// Looping playback: the frame shown at simulation [step]. Each frame is
  /// held for the sprite's own `stepsPerFrame` and the frames wrap over its
  /// frame count; [offset] shifts the cycle by whole frames (so several
  /// copies of one effect do not flicker in step). The index is
  /// `(step ~/ stepsPerFrame + offset) % frameCount`.
  ///
  /// [stepsPerFrame] and [frameCount] override the manifest for a call site
  /// that plays the sprite at another rate or over fewer frames than the
  /// rest of the game; leave them out otherwise. Both must be above 0, and a
  /// [frameCount] override must not exceed the sprite's real frame count (it
  /// plays only the first [frameCount] frames). Null when the id is unknown.
  static ui.Image? frameAt(
    String id,
    int step, {
    int offset = 0,
    int? stepsPerFrame,
    int? frameCount,
  }) {
    assert(stepsPerFrame == null || stepsPerFrame > 0);
    assert(frameCount == null || frameCount > 0);
    final sprite = _sprites[_id(id)];
    if (sprite == null || sprite.frames.isEmpty) return null;
    sprite.lastUsed = ++_clock;
    assert(frameCount == null || frameCount <= sprite.frames.length);
    final count = frameCount ?? sprite.frames.length;
    final index =
        (step ~/ (stepsPerFrame ?? sprite.stepsPerFrame) + offset) % count;
    return sprite.frames[index % sprite.frames.length];
  }

  /// One-shot playback: the frame at progress [t] (0 = start, 1 = end) of an
  /// effect that plays its frames once over its own duration. The index is
  /// `(t * frameCount).floor().clamp(0, frameCount - 1)`, so values outside
  /// 0..1 hold the first or last frame. Null when the id is unknown.
  static ui.Image? frameAtProgress(String id, double t) {
    final sprite = _sprites[_id(id)];
    if (sprite == null || sprite.frames.isEmpty) return null;
    sprite.lastUsed = ++_clock;
    final count = sprite.frames.length;
    return sprite.frames[(t * count).floor().clamp(0, count - 1)];
  }

  /// [id]'s anchor: the point of its images (0..1 on each axis, from the top
  /// left) that painters put on their target point (see [placeRect]).
  /// [center] for sprites without one, drawn and custom sprites included,
  /// and for unknown ids. One map lookup, no allocation.
  static Offset anchor(String id) =>
      _sprites[_id(id)]?.anchor ?? _catalog[_id(id)]?.$3 ?? center;

  /// Pack normalized frames for an owner upload. Rendering does not edit the
  /// owner's file; only the optimized PNG and new frame metadata are uploaded.
  static Future<({SpriteAtlas atlas, Uint8List bytes})> normalizeUpload(
    SpriteAtlas atlas,
    ui.Image sheet, {
    required int frameSize,
    FilterQuality filterQuality = FilterQuality.none,
  }) async {
    if (frameSize != 128 && frameSize != 256) {
      throw ArgumentError('Frame size must be 128 or 256.');
    }
    final count = atlas.sprites.values.fold<int>(
      0,
      (n, s) => n + s.frames.length,
    );
    if (count < 1 || count > 256 || atlas.sprites.length > 64) {
      throw const FormatException(
        'Use 1 to 64 sprites and at most 256 frames.',
      );
    }
    final problems = atlas.problems(
      sheetSize: Size(sheet.width.toDouble(), sheet.height.toDouble()),
    );
    if (problems.isNotEmpty) throw FormatException(problems.join('\n'));
    final columns = math.sqrt(count).ceil(),
        rows = (count / math.sqrt(count).ceil()).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final definitions = <String, SpriteDef>{};
    final images = <ui.Image>[];
    var index = 0;
    try {
      for (final s in atlas.sprites.values) {
        // Never upscale small sources. A fixed cell merely adds transparent padding.
        final maxSource = s.sourceSizes == null
            ? s.frames.map((f) => math.max(f.width, f.height)).reduce(math.max)
            : s.sourceSizes!
                  .map((z) => math.max(z.width, z.height))
                  .reduce(math.max);
        final output = math.max(8, math.min(frameSize, maxSource.ceil() + 4));
        final normalized = SpriteDef(
          id: s.id,
          label: s.label,
          frames: s.frames,
          output: output,
          fit: s.fit,
          anchor: s.anchor,
          displayScale: s.displayScale,
          opacity: s.opacity,
          sourceSizes: s.sourceSizes,
          sourceOffsets: s.sourceOffsets,
          padding: 2,
          stepsPerFrame: s.stepsPerFrame,
        );
        final cuts = await _cutSprite(
          normalized,
          sheet,
          filterQuality: filterQuality,
        );
        images.addAll(cuts);
        final frames = <Rect>[];
        for (final cut in cuts) {
          final x = (index % columns) * frameSize,
              y = (index ~/ columns) * frameSize;
          canvas.drawImage(
            cut,
            Offset(
              x + (frameSize - cut.width) / 2,
              y + (frameSize - cut.height) / 2,
            ),
            Paint()..filterQuality = FilterQuality.none,
          );
          frames.add(
            Rect.fromLTWH(
              x + (frameSize - cut.width) / 2,
              y + (frameSize - cut.height) / 2,
              cut.width.toDouble(),
              cut.height.toDouble(),
            ),
          );
          index++;
        }
        definitions[s.id] = SpriteDef(
          id: s.id,
          label: s.label,
          frames: frames,
          output: output,
          fit: SpriteFit.fill,
          padding: 0,
          anchor: s.anchor,
          displayScale: s.displayScale,
          opacity: s.opacity,
          stepsPerFrame: s.stepsPerFrame,
        );
      }
      final picture = recorder.endRecording();
      ui.Image? packed;
      try {
        packed = await picture.toImage(columns * frameSize, rows * frameSize);
        final data = await packed.toByteData(format: ui.ImageByteFormat.png);
        final bytes = data!.buffer.asUint8List();
        if (bytes.length > 4194304) {
          throw const FormatException(
            'Optimized sheet exceeds 4 MB. Split it into smaller uploads.',
          );
        }
        return (
          atlas: SpriteAtlas(
            sheet: 'optimized.png',
            sheetSize: Size(packed.width.toDouble(), packed.height.toDouble()),
            sprites: definitions,
          ),
          bytes: bytes,
        );
      } finally {
        packed?.dispose();
        picture.dispose();
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  }

  /// Where a [width] x [height] image is drawn so that its [anchor] point
  /// lands on [target]. With [center] it is exactly
  /// `Rect.fromCenter(center: target, ...)`.
  static Rect placeRect(
    Offset target,
    double width,
    double height,
    Offset anchor,
  ) {
    if (anchor == center) {
      return Rect.fromCenter(center: target, width: width, height: height);
    }
    return Rect.fromLTWH(
      target.dx - width * anchor.dx,
      target.dy - height * anchor.dy,
      width,
      height,
    );
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
    _catalog.clear();
    _evicted.clear();
    _pins.clear();
    frozenIds.clear();
    _encodedDrawn.clear();
    cacheBudgetBytes = 128 * 1024 * 1024;
    _customIds.clear();
    _collectionLabels.clear();
    _spriteLabels.clear();
    _owners.clear();
    _problems.clear();
  }

  /// Cuts an already decoded [sheet] (a user upload) under ids
  /// `<idPrefix>.<sprite id>`. Registering the same prefix again replaces its
  /// sprites. [idPrefix] must start with `custom.` so bundled ids stay safe.
  /// Throws [ArgumentError] when the atlas has problems, including a
  /// `sheetSize` that differs from [sheet]'s real size.
  static Future<void> register(
    SpriteAtlas atlas,
    ui.Image sheet, {
    required String idPrefix,
    String? label,
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
      _catalog[full] = (
        sprite.frames.length,
        sprite.stepsPerFrame,
        sprite.anchor,
      );
      if (label != null) _collectionLabels[full] = label;
      if (atlas.sprites[id]?.label case final String name) {
        _spriteLabels[full] = name;
      }
      added.add(full);
    });
    _customIds[idPrefix] = added;
    revision.value++;
  }

  /// Removes the sprites registered under [idPrefix] and frees their images.
  static void unregister(String idPrefix) {
    final old = {
      ...?_customIds.remove(idPrefix),
      ...?_evicted.remove(idPrefix),
    };
    if (old.isEmpty) return;
    for (final id in old) {
      _sprites.remove(id)?.dispose();
      _collectionLabels.remove(id);
      _spriteLabels.remove(id);
      _catalog.remove(id);
    }
    revision.value++;
  }

  /// Adds one bundled sprite (a single frame) that the app draws in code
  /// instead of cutting it from a sheet, such as a pixel-art icon. The whole
  /// [image] goes through the same fit as a manifest frame ([fit],
  /// [output] wide, [outputHeight] tall or square, [padding]) and is stored
  /// under [id] like a sprite from a bundled manifest: `frame(id)` returns it
  /// and a manifest that later names the same id is skipped with a load
  /// problem. There is no `trimCutPadding`: with [SpriteFit.trim] the
  /// measured first cut always fills the whole output (cut padding 0).
  /// [anchor] works like a manifest's (default [center]).
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
    Offset anchor = center,
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
      anchor: anchor,
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
    final sprite = _CutSprite(frames, stepsPerFrame, anchor);
    if (gen != _generation) {
      sprite.dispose();
      return;
    }
    if (_sprites.containsKey(id) || _owners.containsKey(id)) {
      sprite.dispose();
      throw ArgumentError.value(id, 'id', 'is already in use');
    }
    _owners[id] = 'drawn in code';
    _sprites[_id(id)] = sprite;
    if (RegExp(r'^[a-f0-9]{40}$').hasMatch(assetRevision)) {
      await embedDrawn({id: id});
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
    try {
      for (final def in atlas.sprites.values) {
        if (def.frames.isEmpty) continue;
        out[def.id] = _CutSprite(
          await _cutSprite(def, sheet),
          def.stepsPerFrame,
          def.anchor,
        );
        for (final frame in out[def.id]!.frames) {
          _imageScales[frame] = def.displayScale;
          _imageOpacity[frame] = def.opacity;
        }
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
    ui.Image sheet, {
    FilterQuality filterQuality = FilterQuality.none,
  }) async {
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
      for (var frameIndex = 0; frameIndex < sources.length; frameIndex++) {
        final source = sources[frameIndex];
        if (def.fit == SpriteFit.trim) {
          frames.add(
            await _trimmed(
              sheet,
              source,
              size,
              height,
              def.padding,
              def.trimCutPadding,
              filterQuality: filterQuality,
            ),
          );
          continue;
        }
        final Rect dest;
        if (def.sourceSizes != null && def.sourceOffsets != null) {
          final original = def.sourceSizes![frameIndex];
          final offset = def.sourceOffsets![frameIndex];
          final box = _contain(original, inner);
          final scale = box.width / original.width;
          dest = Rect.fromLTWH(
            box.left + offset.dx * scale,
            box.top + offset.dy * scale,
            source.width * scale,
            source.height * scale,
          );
        } else if (def.sharedBand) {
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
        frames.add(
          await _draw(
            sheet,
            source,
            dest,
            size,
            height,
            filterQuality: filterQuality,
          ),
        );
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
    int height, {
    FilterQuality filterQuality = FilterQuality.none,
  }) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      dest,
      Paint()..filterQuality = filterQuality,
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
    int cutPadding, {
    FilterQuality filterQuality = FilterQuality.none,
  }) async {
    final full = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final cut = await _draw(
      image,
      source,
      _contain(source.size, full.deflate(cutPadding.toDouble())),
      width,
      height,
      filterQuality: filterQuality,
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
        filterQuality: filterQuality,
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
  int references = 1;
  int lastUsed = 0;
  final List<ui.Image> frames;
  final int stepsPerFrame;
  final Offset anchor;
  _CutSprite(this.frames, this.stepsPerFrame, this.anchor);

  void dispose() {
    if (--references > 0) return;
    for (final f in frames) {
      f.dispose();
    }
  }
}
