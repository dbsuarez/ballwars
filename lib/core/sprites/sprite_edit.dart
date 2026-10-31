import 'dart:typed_data';
import 'dart:ui';
import 'sprite_atlas.dart';
import 'sprite_import.dart';

/// Non-destructive metadata edits; indexes always refer to the original cuts.
class SpriteEdit {
  String? name;
  int? stepsPerFrame;
  Offset? anchor;
  double? displayScale;
  double? opacity;
  int rotationQuarterTurns = 0;
  bool flipHorizontal = false;
  bool flipVertical = false;
  /// Playback sequence. Source indexes may repeat to hold a frame longer.
  List<int>? order;
  static const int maxPlaybackFrames = 240;
  final Set<int> excluded = {};
  bool allowBlankFrames = false;
  List<int> indexes(int count) => (order ?? List.generate(count, (i) => i))
      .where((i) => !excluded.contains(i))
      .toList();
  SpriteDef apply(SpriteDef original) {
    final value = name?.trim();
    final id = value == null
        ? original.id
        : RegExp('[a-zA-Z0-9]').hasMatch(value)
        ? SpriteImport.name(value)
        : original.id;
    if (value != null && (value.isEmpty || value.length > 80)) {
      throw const FormatException(
        'Sprite names must contain 1 to 80 characters.',
      );
    }
    final indices = indexes(original.frames.length);
    if (order != null && order!.isEmpty) {
      throw FormatException(
        '$id needs at least one playback frame.',
      );
    }
    if (indices.length > maxPlaybackFrames) {
      throw FormatException(
        '$id exceeds the $maxPlaybackFrames playback frame limit.',
      );
    }
    if (order != null && order!.any((i) => i < 0 || i >= original.frames.length)) {
      throw FormatException(
        '$id cuts changed. Reset this sprite before editing the new frames.',
      );
    }
    if (indices.isEmpty) {
      throw FormatException('$id needs at least one included frame.');
    }
    if (indices.any((i) => i < 0 || i >= original.frames.length)) {
      throw FormatException(
        '$id frame order is out of range. Reset this sprite.',
      );
    }
    return SpriteDef(
      id: id,
      label: value ?? original.label,
      frames: [for (final i in indices) original.frames[i]],
      output: original.output,
      outputHeight: original.outputHeight,
      fit: original.fit,
      anchor: anchor ?? original.anchor,
      displayScale: displayScale ?? original.displayScale,
      opacity: opacity ?? original.opacity,
      stepsPerFrame: stepsPerFrame ?? original.stepsPerFrame,
      padding: original.padding,
      sourceSizes: original.sourceSizes == null
          ? null
          : [for (final i in indices) original.sourceSizes![i]],
      sourceOffsets: original.sourceOffsets == null
          ? null
          : [for (final i in indices) original.sourceOffsets![i]],
      sharedBand: original.sharedBand,
      bleedOk: original.bleedOk,
      bleedNote: original.bleedNote,
      trimCutPadding: original.trimCutPadding,
    );
  }
}

class SpriteFrameDiagnostics {
  const SpriteFrameDiagnostics({
    required this.pixels,
    required this.visible,
    required this.transparent,
    required this.partial,
    required this.edges,
    required this.bounds,
  });
  final int pixels, visible, transparent, partial, edges;
  final Rect? bounds;
  bool get blank => visible == 0;
  double get transparencyPercent =>
      pixels == 0 ? 100 : 100 * transparent / pixels;
  static SpriteFrameDiagnostics inspect(
    Uint8List rgba,
    int width,
    int height,
    Rect frame,
  ) {
    if (rgba.length != width * height * 4 ||
        frame.left < 0 ||
        frame.top < 0 ||
        frame.right > width ||
        frame.bottom > height ||
        frame.width <= 0 ||
        frame.height <= 0) {
      throw const FormatException('Cannot inspect an invalid frame rectangle.');
    }
    var pixels = 0, visible = 0, transparent = 0, partial = 0, edges = 0;
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = frame.top.toInt(); y < frame.bottom; y++) {
      for (var x = frame.left.toInt(); x < frame.right; x++) {
        final alpha = rgba[(y * width + x) * 4 + 3];
        pixels++;
        if (alpha < 255) transparent++;
        if (alpha > 0 && alpha < 255) partial++;
        if (alpha < 24) continue;
        visible++;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        if (x == frame.left ||
            x == frame.right - 1 ||
            y == frame.top ||
            y == frame.bottom - 1) {
          edges++;
        }
      }
    }
    return SpriteFrameDiagnostics(
      pixels: pixels,
      visible: visible,
      transparent: transparent,
      partial: partial,
      edges: edges,
      bounds: visible == 0
          ? null
          : Rect.fromLTRB(
              left.toDouble(),
              top.toDouble(),
              right + 1.0,
              bottom + 1.0,
            ),
    );
  }
}
