import 'dart:typed_data';
import 'dart:ui' as ui;

class CanvasImageHelper {
  CanvasImageHelper._();

  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
