import 'dart:ui' as ui;

import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records where images land, following translate/save/restore. The
/// painter calls below never rotate (the ball moves along +x).
class _RecordingCanvas implements Canvas {
  final List<Rect> images = [];
  final List<Offset> _stack = [];
  Offset _origin = Offset.zero;

  @override
  void save() => _stack.add(_origin);

  @override
  void restore() => _origin = _stack.removeLast();

  @override
  void translate(double dx, double dy) => _origin += Offset(dx, dy);

  @override
  void rotate(double radians) => expect(radians, 0);

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      images.add(dst.shift(_origin));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<ui.Image> _square() {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    const Rect.fromLTWH(0, 0, 16, 16),
    Paint()..color = const Color(0xFF00FF00),
  );
  return rec.endRecording().toImage(16, 16);
}

/// Where the speed streak lands for a ball at (100, 100) moving along +x.
Rect _streakRect() {
  final ball = SimulationBall(
    config: CustomBall(
      id: 'a',
      name: 'a',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
    ),
    position: const Offset(100, 100),
    velocity: const Offset(10, 0),
    radius: 10,
    lineCount: 0,
  )..speedLeft = 5;
  final canvas = _RecordingCanvas();
  PowerUpPainter.paintSpeedTrail(canvas, ball);
  return canvas.images.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final id = PowerUpSprites.effectId(EffectSprite.speedStreak);

  tearDown(SpriteRegistry.resetForTest);

  test('the painter puts a sprite\'s anchor on its target point', () async {
    // Target: position - dir * r * 1.25 = (87.5, 100); half size r * 1.65.
    const target = Offset(87.5, 100);
    const side = 10 * 1.65 * 2;
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final image = await _square();
      SpriteRegistry.resetForTest();
      await SpriteRegistry.registerDrawn(id, image, output: 32);
      expect(
        _streakRect(),
        Rect.fromCenter(center: target, width: side, height: side),
      );

      SpriteRegistry.resetForTest();
      await SpriteRegistry.registerDrawn(
        id,
        image,
        output: 32,
        anchor: const Offset(0, 0.5),
      );
      // The left middle of the image sits on the target.
      expect(
        _streakRect(),
        Rect.fromLTWH(target.dx, target.dy - side / 2, side, side),
      );

      SpriteRegistry.resetForTest();
      await SpriteRegistry.registerDrawn(
        id,
        image,
        output: 32,
        anchor: const Offset(1, 1),
      );
      expect(
        _streakRect(),
        Rect.fromLTWH(target.dx - side, target.dy - side, side, side),
      );
      image.dispose();
    });
  });

  test('PowerUpSprites.load registers the drawn icons again after a reset',
      () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      SpriteRegistry.resetForTest();
      await PowerUpSprites.load();
      for (final kind in PowerUpSprites.pixelArtOnly) {
        expect(SpriteRegistry.has(PowerUpSprites.iconId(kind)), isTrue);
      }
      SpriteRegistry.resetForTest();
      for (final kind in PowerUpSprites.pixelArtOnly) {
        expect(SpriteRegistry.has(PowerUpSprites.iconId(kind)), isFalse);
      }
      await PowerUpSprites.load();
      expect(SpriteRegistry.loadProblems, isEmpty);
      for (final kind in PowerUpSprites.pixelArtOnly) {
        final icon = PowerUpSprites.of(kind);
        expect(icon, isNotNull, reason: '$kind');
        expect((icon!.width, icon.height), (64, 64));
      }
    });
  });
}
