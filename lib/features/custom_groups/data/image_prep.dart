import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../../core/utils/canvas_image_helper.dart';
import '../../ball_management/domain/custom_ball.dart';

/// A picked image made ready for upload: a [size] x [size] PNG (well under
/// the bucket's 512 KB limit) plus a suggested line color.
class PreparedImage {
  final Uint8List png;
  final Color suggestedColor;

  const PreparedImage(this.png, this.suggestedColor);
}

class ImagePrep {
  ImagePrep._();

  static const int size = 256;

  /// [crop] (in the image's pixels, from the cropper) is the square the user
  /// framed; it fills the output. Without it, logos are fitted whole into a
  /// transparent square and cover images (photos, flags) are center-cropped.
  static Future<PreparedImage> prepare(Uint8List bytes, BallImageStyle style, {Rect? crop}) async {
    final source = await CanvasImageHelper.decode(bytes);
    try {
      return await fromImage(source, style, crop: crop);
    } finally {
      source.dispose();
    }
  }

  /// Decodes a picked picture for framing, scaled down so its longer side is
  /// at most [maxSide] (big photos would otherwise use a lot of memory).
  static Future<ui.Image> decodeForCropping(Uint8List bytes, {int maxSide = 1024}) async {
    final full = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(full);
    final w = descriptor.width, h = descriptor.height;
    final codec = await descriptor.instantiateCodec(
      targetWidth: w >= h && w > maxSide ? maxSide : null,
      targetHeight: h > w && h > maxSide ? maxSide : null,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    full.dispose();
    return frame.image;
  }

  /// Same as [prepare], from an already decoded [source] (not disposed).
  static Future<PreparedImage> fromImage(ui.Image source, BallImageStyle style, {Rect? crop}) async {
    {
      final w = source.width.toDouble(), h = source.height.toDouble();
      final Rect src;
      final Rect dst;
      if (crop != null) {
        src = crop;
        dst = const Rect.fromLTWH(0, 0, size + 0.0, size + 0.0);
      } else if (style == BallImageStyle.cover) {
        final side = w < h ? w : h;
        src = Rect.fromLTWH((w - side) / 2, (h - side) / 2, side, side);
        dst = const Rect.fromLTWH(0, 0, size + 0.0, size + 0.0);
      } else {
        final scale = size / (w > h ? w : h);
        src = Rect.fromLTWH(0, 0, w, h);
        dst = Rect.fromCenter(center: const Offset(size / 2, size / 2), width: w * scale, height: h * scale);
      }

      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(source, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.high);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      picture.dispose();
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        return PreparedImage(png, dominantColor(rgba));
      } finally {
        image.dispose();
      }
    }
  }

  /// The most common vivid color in raw RGBA pixels, ignoring transparent,
  /// near-white, near-black and gray pixels; dark gray if there is none.
  static Color dominantColor(Uint8List rgba) {
    final counts = <int, int>{};
    // Every 3rd pixel: fast, and odd enough not to alias with striped images.
    for (var i = 0; i + 3 < rgba.length; i += 12) {
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2], a = rgba[i + 3];
      if (a < 200) continue;
      final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (max - min < 40 || max < 40 || min > 225) continue;
      // Bucket to 4 bits per channel so similar shades count together.
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return const Color(0xFF444444);
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    int channel(int shift) => (((best >> shift) & 0xF) << 4) | 0x8;
    return Color.fromARGB(255, channel(8), channel(4), channel(0));
  }
}
