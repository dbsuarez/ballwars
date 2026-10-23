import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/custom_groups/data/image_prep.dart';

/// Also run in a browser (the web engine has its own image decoding):
///   flutter test --platform chrome test/features/custom_groups/data/image_prep_decode_test.dart
void main() {
  Future<Uint8List> png(int w, int h) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.orange);
    final image = await recorder.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  test('a big picture is decoded scaled down to the longer side limit', () async {
    final image = await ImagePrep.decodeForCropping(await png(1600, 900), maxSide: 800);
    expect(image.width, 800);
    expect(image.height, 450);
  });

  test('a small picture keeps its size', () async {
    final image = await ImagePrep.decodeForCropping(await png(300, 500), maxSide: 800);
    expect((image.width, image.height), (300, 500));
  });
}
