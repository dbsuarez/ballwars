import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Contract for every generated or manually added sprite sheet.
///
/// The loader rejects dimensions that do not match the declared fixed grid,
/// crops each cell by [safeInset], centers it with `BoxFit.contain`, and emits
/// isolated frames. That makes neighboring-cell bleed and rectangular atlas
/// backgrounds impossible at paint time.
class SpriteSheetSpec {
  const SpriteSheetSpec({
    required this.name,
    required this.asset,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    this.safeInset = 0,
    this.outputSize = 96,
  });

  final String name;
  final String asset;
  final int columns;
  final int rows;
  final int cellWidth;
  final int cellHeight;
  final int safeInset;
  final int outputSize;

  int get frameCount => columns * rows;

  void validateDimensions(int width, int height) {
    if (columns <= 0 || rows <= 0 || cellWidth <= 0 || cellHeight <= 0) {
      throw FormatException('$name has an invalid sprite grid.');
    }
    if (safeInset < 0 ||
        safeInset * 2 >= cellWidth ||
        safeInset * 2 >= cellHeight) {
      throw FormatException('$name has an invalid safe area.');
    }
    final expectedWidth = columns * cellWidth;
    final expectedHeight = rows * cellHeight;
    if (width != expectedWidth || height != expectedHeight) {
      throw FormatException(
        '$name must be ${expectedWidth}x$expectedHeight pixels '
        '(${columns}x$rows cells of ${cellWidth}x$cellHeight); got ${width}x$height.',
      );
    }
  }
}

class SpriteAssetPipeline {
  SpriteAssetPipeline._();

  /// Used for both built-in sheets and manually added bundled sheets.
  static Future<List<ui.Image>> load(SpriteSheetSpec spec) async {
    final data = await rootBundle.load(spec.asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final sheet = (await codec.getNextFrame()).image;
    codec.dispose();
    spec.validateDimensions(sheet.width, sheet.height);
    await _validateTransparentCorners(sheet, spec);
    final frames = <ui.Image>[];
    try {
      for (var index = 0; index < spec.frameCount; index++) {
        final column = index % spec.columns;
        final row = index ~/ spec.columns;
        final source = Rect.fromLTWH(
          (column * spec.cellWidth + spec.safeInset).toDouble(),
          (row * spec.cellHeight + spec.safeInset).toDouble(),
          (spec.cellWidth - spec.safeInset * 2).toDouble(),
          (spec.cellHeight - spec.safeInset * 2).toDouble(),
        );
        final destinationBounds = Rect.fromLTWH(
          2,
          2,
          spec.outputSize - 4,
          spec.outputSize - 4,
        );
        final fitted = applyBoxFit(
          BoxFit.contain,
          source.size,
          destinationBounds.size,
        );
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          sheet,
          source,
          Alignment.center.inscribe(fitted.destination, destinationBounds),
          Paint()..filterQuality = FilterQuality.none,
        );
        final picture = recorder.endRecording();
        frames.add(await picture.toImage(spec.outputSize, spec.outputSize));
        picture.dispose();
      }
      return frames;
    } finally {
      sheet.dispose();
    }
  }

  static Future<void> _validateTransparentCorners(
    ui.Image sheet,
    SpriteSheetSpec spec,
  ) async {
    final bytes = await sheet.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) {
      throw FormatException('${spec.name} transparency could not be read.');
    }
    for (var index = 0; index < spec.frameCount; index++) {
      final left = (index % spec.columns) * spec.cellWidth;
      final top = (index ~/ spec.columns) * spec.cellHeight;
      final points = [
        (left + 1, top + 1),
        (left + spec.cellWidth - 2, top + 1),
        (left + 1, top + spec.cellHeight - 2),
        (left + spec.cellWidth - 2, top + spec.cellHeight - 2),
      ];
      for (final (x, y) in points) {
        final alpha = bytes.getUint8((y * sheet.width + x) * 4 + 3);
        if (alpha > 8) {
          throw FormatException(
            '${spec.name} frame ${index + 1} has an opaque cell corner. '
            'Effect bounds must be transparent.',
          );
        }
      }
    }
  }
}
