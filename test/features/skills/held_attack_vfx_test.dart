import 'dart:ui' as ui;

import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImageCanvas implements ui.Canvas {
  final List<ui.Image> images = [];

  @override
  void drawImageRect(ui.Image image, ui.Rect source, ui.Rect destination,
      ui.Paint paint) {
    images.add(image);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('held attack VFX draws only during the visual swing, not at rest', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      SpriteRegistry.resetForTest();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawPaint(ui.Paint()..color = const ui.Color(0xff00ffff));
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      await SpriteRegistry.register(
        SpriteImport.grid(sheet: 'slash-vfx.png', width: 16, height: 16),
        image,
        idPrefix: 'custom.slash-vfx',
      );
      const id = 'custom.slash-vfx.sprite';
      expect(SpriteRegistry.has(id), isTrue);

      final ball = SimulationBall(
        config: const CustomBall(id: 'slash-test', name: 'Sword',
          primaryColor: ui.Color(0xffff0000), glowColor: ui.Color(0xffff0000)),
        position: ui.Offset.zero, velocity: const ui.Offset(-1, 0),
        radius: 20, lineCount: 0,
      );
      ball.equipWeapon(PowerUpKind.sword, dualWield: false);
      final atRest = _ImageCanvas();
      PowerUpPainter.paintBallEffects(atRest, ball,
        heldAttackAnimation: (_, _) => HeldAttackAnimation.slash,
        heldAttackVfxSpriteId: (_, _) => id,
        firedWeaponHoldLeft: (_, _) => 0,
      );
      expect(atRest.images, isNot(contains(same(SpriteRegistry.frame(id)))));

      final attacking = _ImageCanvas();
      PowerUpPainter.paintBallEffects(attacking, ball,
        heldAttackAnimation: (_, _) => HeldAttackAnimation.slash,
        heldAttackVfxSpriteId: (_, _) => id,
        firedWeaponHoldLeft: (_, _) => 15,
      );
      expect(attacking.images, contains(same(SpriteRegistry.frame(id))));
      SpriteRegistry.unregister('custom.slash-vfx');
      image.dispose();
      picture.dispose();
    });
  });
}
