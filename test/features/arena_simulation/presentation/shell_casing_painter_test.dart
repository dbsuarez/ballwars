import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 64;

ShellCasing _casing({String? spriteId, double size = 1, double angle = 0.7}) =>
    ShellCasing(
      position: const Offset(32, 32),
      velocity: Offset.zero,
      angle: angle,
      spriteId: spriteId,
      size: size,
    );

/// The brass casing exactly as it was drawn before shell settings existed.
void _paintLegacy(Canvas canvas, ShellCasing casing, double r) {
  canvas.save();
  canvas.translate(casing.position.dx, casing.position.dy);
  canvas.rotate(casing.angle);
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: math.max(2.5, r * 0.2),
      height: math.max(1.5, r * 0.1),
    ),
    const Radius.circular(1),
  );
  canvas.drawRRect(body, Paint()..color = const Color(0xFFD8A63A));
  canvas.drawLine(
    Offset(body.right - 0.7, body.top),
    Offset(body.right - 0.7, body.bottom),
    Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFE09A),
  );
  canvas.restore();
}

Future<Uint8List> _render(void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_size, _size);
  final bytes = await image.toByteData();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

int _opaque(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 0) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(SpriteRegistry.resetForTest);

  test('default casings paint the same pixels as before', () async {
    for (final r in const [8.0, 14.0, 30.0]) {
      final casing = _casing();
      final want = await _render((c) => _paintLegacy(c, casing, r));
      final got = await _render(
        (c) => PowerUpPainter.paintShellCasing(c, casing, r),
      );
      expect(got, want, reason: 'r $r');
    }
  });

  test('an unknown sprite id falls back to the brass shell', () async {
    final want = await _render((c) => _paintLegacy(c, _casing(), 14));
    final got = await _render(
      (c) => PowerUpPainter.paintShellCasing(
        c,
        _casing(spriteId: 'projectile.no-such-sprite'),
        14,
      ),
    );
    expect(got, want);
  });

  test('shell size scales the brass shell', () async {
    final small = _opaque(
      await _render((c) => PowerUpPainter.paintShellCasing(c, _casing(), 14)),
    );
    final big = _opaque(
      await _render(
        (c) => PowerUpPainter.paintShellCasing(c, _casing(size: 3), 14),
      ),
    );
    expect(big, greaterThan(small * 4));
  });

  test('a sprite shell draws the sprite, centered and fitted', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 16, 8),
      Paint()..color = const Color(0xFF00FF00),
    );
    final image = await recorder.endRecording().toImage(16, 8);
    await SpriteRegistry.registerDrawn(
      'projectile.test-shell',
      image,
      output: 16,
      outputHeight: 8,
      padding: 0,
    );
    image.dispose();
    expect(SpriteRegistry.has('projectile.test-shell'), isTrue);
    final rgba = await _render(
      (c) => PowerUpPainter.paintShellCasing(
        c,
        _casing(spriteId: 'projectile.test-shell', size: 4, angle: 0),
        14,
      ),
    );
    // Brass length at r 14 is 2.8; times 4 is an 11.2 px box: the 2:1 sprite is 11.2 x 5.6.
    var green = 0;
    var minX = _size, maxX = -1, minY = _size, maxY = -1;
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        final i = (y * _size + x) * 4;
        if (rgba[i + 3] == 0) continue;
        // Green only (edges are anti-aliased, so partly covered).
        expect(rgba[i], 0);
        expect(rgba[i + 2], 0);
        expect(rgba[i + 1], greaterThan(0));
        green++;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
    expect(green, greaterThan(40));
    expect((minX + maxX) / 2, closeTo(31.5, 1));
    expect((minY + maxY) / 2, closeTo(31.5, 1));
    expect(maxX - minX + 1, inInclusiveRange(11, 13));
    expect(maxY - minY + 1, inInclusiveRange(5, 7));
  });
}
