import 'dart:ui' as ui;
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter_test/flutter_test.dart';

class ImageCanvas implements ui.Canvas {
  final List<ui.Image> images = [];
  @override
  void drawImageRect(
    ui.Image image,
    ui.Rect src,
    ui.Rect dst,
    ui.Paint paint,
  ) => images.add(image);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'arena renders assigned token, held art, projectile and explosion; deletion falls back safely',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        SpriteRegistry.resetForTest();
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawPaint(ui.Paint()..color = const ui.Color(0xff00ff00));
        final picture = recorder.endRecording();
        final sheet = await picture.toImage(48, 16);
        await SpriteRegistry.register(
          SpriteImport.grid(
            sheet: 'a.png',
            width: 48,
            height: 16,
            columns: 3,
            animation: false,
          ),
          sheet,
          idPrefix: 'custom.a',
        );
        final skill = SkillLibrary.defaults
            .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
            .copyWith(
              iconSpriteId: 'custom.a.sprite-1',
              projectileSpriteId: 'custom.a.sprite-2',
              impactSpriteId: 'custom.a.sprite-3',
            );
        final library = SkillLibrary.defaults.withDefinition(
          skill,
          PowerUpConfig.defaults,
        );
        final controller = MatchSimulationController(
          const [
            CustomBall(
              id: 'a',
              name: 'A',
              primaryColor: ui.Color(0xffff0000),
              glowColor: ui.Color(0xffff0000),
            ),
            CustomBall(
              id: 'b',
              name: 'B',
              primaryColor: ui.Color(0xff0000ff),
              glowColor: ui.Color(0xff0000ff),
            ),
          ],
          arenaRadius: 260,
          seed: 1,
          mode: MatchMode.arsenal,
          skillLibrary: library,
          lookAhead: false,
        );
        final p = controller.powerUps!, owner = controller.state.balls.first;
        owner.equipWeapon(PowerUpKind.pistol, dualWield: false);
        p.field.add(
          FieldPowerUp(
            kind: PowerUpKind.pistol,
            position: const ui.Offset(0, 60),
            spawnStep: 0,
          ),
        );
        p.projectiles.add(
          Projectile(
            owner: owner,
            kind: PowerUpKind.pistol,
            position: ui.Offset.zero,
            velocity: const ui.Offset(100, 0),
          ),
        );
        p.explosions.add(
          Explosion(
            position: const ui.Offset(30, 30),
            radius: 70,
            kind: PowerUpKind.pistol,
          ),
        );
        final canvas = ImageCanvas();
        ArenaPainter(
          state: controller.state,
          arenaRadius: 260,
          rimAngle: 0,
          look: BallLook.faces,
        ).paint(canvas, const ui.Size(600, 600));
        for (var i = 1; i <= 3; i++) {
          expect(
            canvas.images,
            contains(same(SpriteRegistry.frame('custom.a.sprite-$i'))),
          );
        }
        expect(
          canvas.images
              .where(
                (image) =>
                    identical(image, SpriteRegistry.frame('custom.a.sprite-1')),
              )
              .length,
          greaterThanOrEqualTo(2),
        );
        SpriteRegistry.unregister('custom.a');
        expect(
          () => ArenaPainter(
            state: controller.state,
            arenaRadius: 260,
            rimAngle: 0,
          ).paint(ImageCanvas(), const ui.Size(600, 600)),
          returnsNormally,
        );
        sheet.dispose();
        picture.dispose();
      });
    },
  );
  test('slots survive full and compact libraries and explicit null clears', () {
    final original = SkillLibrary.defaults.builtIn(
      PowerUpKind.boomerang,
      PowerUpConfig.defaults,
    );
    final s = original.copyWith(
      iconSpriteId: 'custom.a.icon',
      projectileSpriteId: 'custom.a.shot',
      impactSpriteId: 'custom.a.boom',
    );
    final library = SkillLibrary(overrides: {s.id: s});
    for (final json in [library.toJson(), library.toCompactJson()]) {
      final result = SkillLibrary.fromJson(
        json,
      ).builtIn(PowerUpKind.boomerang, PowerUpConfig.defaults);
      expect(result.iconSpriteId, s.iconSpriteId);
      expect(result.projectileSpriteId, s.projectileSpriteId);
      expect(result.impactSpriteId, s.impactSpriteId);
    }
    expect(s.copyWith(iconSpriteId: null).iconSpriteId, isNull);
    expect(s.copyWith().impactSpriteId, s.impactSpriteId);
    final longest = 'custom.01234567-0123-0123-0123-012345678901.${'x' * 40}';
    expect(s.copyWith(iconSpriteId: longest).validated().iconSpriteId, longest);
  });
  test(
    'registered custom frame is selected and missing art falls back',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        SpriteRegistry.resetForTest();
        final r = ui.PictureRecorder();
        ui.Canvas(r).drawPaint(ui.Paint()..color = const ui.Color(0xff00ff00));
        final p = r.endRecording();
        final image = await p.toImage(16, 16);
        await SpriteRegistry.register(
          SpriteImport.grid(sheet: 'a.png', width: 16, height: 16),
          image,
          idPrefix: 'custom.a',
        );
        expect(
          PowerUpPainter.skillSprite('custom.a.sprite', 'missing', 0),
          same(SpriteRegistry.frame('custom.a.sprite')),
        );
        expect(
          PowerUpPainter.skillSprite(
            'custom.deleted.icon',
            'custom.a.sprite',
            0,
          ),
          same(SpriteRegistry.frame('custom.a.sprite')),
        );
        SpriteRegistry.unregister('custom.a');
        expect(
          PowerUpPainter.skillSprite('custom.a.sprite', 'missing', 0),
          isNull,
        );
        image.dispose();
        p.dispose();
      });
    },
  );
}
