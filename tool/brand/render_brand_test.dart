// Renders the app icon and splash images from BallWarsLogoPainter into
// assets/brand/. Run:  flutter test tool/brand/render_brand_test.dart
// then:                dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/widgets/ball_wars_logo.dart';

Future<void> _render(String name, int side, {required double logo, Color? background, double corner = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final full = Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble());
  if (background != null) {
    canvas.drawRRect(RRect.fromRectAndRadius(full, Radius.circular(side * corner)), Paint()..color = background);
  }
  final logoSide = side * logo;
  canvas.translate((side - logoSide) / 2, (side - logoSide) / 2);
  const BallWarsLogoPainter().paint(canvas, Size.square(logoSide));
  final image = await recorder.endRecording().toImage(side, side);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('assets/brand/$name').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render brand images', () async {
    Directory('assets/brand').createSync(recursive: true);
    const bg = BallWarsLogoPainter.midnight;
    // Launcher icon (legacy Android, iOS, web): full square.
    await _render('icon.png', 1024, logo: 0.76, background: bg);
    // Android adaptive foreground: the logo inside the 66% safe zone.
    await _render('icon_foreground.png', 1024, logo: 0.58);
    // Splash: logo on transparent (placed on the midnight color). Shown at
    // 192 dp, so the logo is ~116 dp, the size the loading screen draws it.
    await _render('splash.png', 768, logo: 0.6);
    // Android 12+ splash icon: shown at 288 dp; same ~116 dp logo, well
    // inside the circle (2/3 of the image) that Android keeps.
    await _render('splash_android12.png', 1152, logo: 0.4);
  });
}
