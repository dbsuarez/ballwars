import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/canvas_image_helper.dart';

Future<Uint8List> _tinyPngBytes() async {
  // 1x1 transparent PNG, valid and tiny - good for a fast decode test.
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  return base64Decode(base64Png);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decode returns a ui.Image matching the source pixel dimensions', () async {
    final bytes = await _tinyPngBytes();
    final ui.Image image = await CanvasImageHelper.decode(bytes);
    expect(image.width, 1);
    expect(image.height, 1);
  });
}
