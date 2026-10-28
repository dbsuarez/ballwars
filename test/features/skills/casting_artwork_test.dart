import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_edit.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const balls = [
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
];
MatchSimulationController setup(PowerUpKind kind, {bool follows = true}) {
  final skill = SkillLibrary.defaults
      .builtIn(kind, PowerUpConfig.defaults)
      .copyWith(
        castingSpriteId: 'custom.art.sprite-1',
        impactSpriteId: 'custom.art.sprite-2',
        castingDurationSeconds: .1,
        castingScale: 1.5,
        castingFollowsActive: follows,
      );
  final m = MatchSimulationController(
    balls,
    arenaRadius: 260,
    mode: MatchMode.arsenal,
    seed: 3,
    lookAhead: false,
    skillLibrary: SkillLibrary.defaults.withDefinition(
      skill,
      PowerUpConfig.defaults,
    ),
  );
  m.powerUps!.automaticSpawning = false;
  m.state.balls[0].position = const ui.Offset(-80, 0);
  m.state.balls[1].position = const ui.Offset(80, 0);
  for (final ball in m.state.balls) {
    ball.velocity = ui.Offset.zero;
  }
  final item = FieldPowerUp(
    kind: kind,
    position: m.state.balls.first.position,
    spawnStep: 0,
  );
  m.powerUps!.field.add(item);
  m.powerUps!.pickUp(m.state.balls.first, item);
  return m;
}

class CastCanvas implements ui.Canvas {
  final images = <ui.Image>[];
  final targets = <ui.Rect>[];
  @override
  void drawImageRect(
    ui.Image image,
    ui.Rect source,
    ui.Rect target,
    ui.Paint paint,
  ) {
    images.add(image);
    targets.add(target);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'saved sprite opacity survives normalization and blends with what is behind it',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        SpriteRegistry.resetForTest();
        final r = ui.PictureRecorder();
        ui.Canvas(r).drawPaint(ui.Paint()..color = const ui.Color(0xff00ff00));
        final p = r.endRecording(), source = await p.toImage(16, 16);
        final base = SpriteImport.grid(
          sheet: 'green.png',
          width: 16,
          height: 16,
        );
        final edited = SpriteAtlas(
          sheet: base.sheet,
          sprites: {
            for (final sprite in base.sprites.values)
              sprite.id: (SpriteEdit()..opacity = .5).apply(sprite),
          },
        );
        final packed = await SpriteRegistry.normalizeUpload(
          edited,
          source,
          frameSize: 128,
        );
        final decoded = SpriteAtlas.parse(spriteAtlasJson(packed.atlas));
        expect(decoded.sprites.values.single.opacity, .5);
        final codec = await ui.instantiateImageCodec(packed.bytes);
        final sheet = (await codec.getNextFrame()).image;
        await SpriteRegistry.register(
          decoded,
          sheet,
          idPrefix: 'custom.opacity',
        );
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.drawPaint(ui.Paint()..color = const ui.Color(0xffff0000));
        HarpoonCinematic.paintRaster(
          canvas,
          SpriteRegistry.frame('custom.opacity.sprite')!,
          const ui.Offset(16, 16),
          16,
          anchor: SpriteRegistry.center,
        );
        final picture = recorder.endRecording(),
            image = await picture.toImage(32, 32);
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (16 * 32 + 16) * 4;
        expect(rgba.getUint8(offset), inInclusiveRange(126, 129));
        expect(rgba.getUint8(offset + 1), inInclusiveRange(126, 129));
        expect(rgba.getUint8(offset + 2), 0);
        expect(rgba.getUint8(offset + 3), 255);
        SpriteRegistry.unregister('custom.opacity');
        codec.dispose();
        sheet.dispose();
        source.dispose();
        p.dispose();
        picture.dispose();
        image.dispose();
      });
    },
  );
  test(
    'facing choices are model settings, preserve rotation, and mirror either direction',
    () {
      for (final mode in SkillHeldFacing.values) {
        final skill = SkillLibrary.defaults
            .builtIn(PowerUpKind.shield, PowerUpConfig.defaults)
            .copyWith(heldFacing: mode);
        expect(SkillDefinition.fromJson(skill.toJson())!.heldFacing, mode);
      }
      final right = PowerUpPainter.heldFacingTransform(
        0,
        -90,
        SkillHeldFacing.mirror,
        shield: true,
      );
      final left = PowerUpPainter.heldFacingTransform(
        math.pi,
        -90,
        SkillHeldFacing.mirror,
        shield: true,
      );
      expect(right.angle, 0);
      expect(right.flip, false);
      expect(left.angle, math.pi);
      expect(left.flip, true);
      for (final angle in [0.0, math.pi / 2, math.pi]) {
        final upright = PowerUpPainter.heldFacingTransform(
          angle,
          -90,
          SkillHeldFacing.upright,
          shield: true,
        );
        expect(upright.angle, 0);
        expect(upright.flip, false);
      }
    },
  );
  test(
    'casting settings round-trip independently from impact and can be cleared',
    () {
      final s = SkillLibrary.defaults
          .builtIn(PowerUpKind.energyWave, PowerUpConfig.defaults)
          .copyWith(
            castingSpriteId: 'custom.art.cast',
            impactSpriteId: 'custom.art.hit',
            castingDurationSeconds: 2,
            castingScale: 3,
            castingFollowsActive: false,
          );
      final library = SkillLibrary.defaults.withDefinition(
        s,
        PowerUpConfig.defaults,
      );
      for (final json in [library.toJson(), library.toCompactJson()]) {
        final result = SkillLibrary.fromJson(
          json,
        ).builtIn(s.baseKind, PowerUpConfig.defaults);
        expect(result.castingSpriteId, s.castingSpriteId);
        expect(result.impactSpriteId, s.impactSpriteId);
        expect(result.castingDurationSeconds, 2);
        expect(result.castingScale, 3);
        expect(result.castingFollowsActive, false);
      }
      expect(s.copyWith(castingSpriteId: null).castingSpriteId, isNull);
      expect(
        s.copyWith(castingSpriteId: null).impactSpriteId,
        s.impactSpriteId,
      );
      final bad = s
          .copyWith(
            castingDurationSeconds: double.nan,
            castingScale: double.infinity,
          )
          .validated();
      expect(bad.castingDurationSeconds, .5);
      expect(bad.castingScale, 1);
    },
  );
  test(
    'timed casting expires independently from a lasting power-up and clears on respawn',
    () {
      final m = setup(PowerUpKind.speed), p = m.powerUps!;
      expect(p.castingArtwork, hasLength(1));
      for (var i = 0; i < 6; i++) {
        p.step();
      }
      expect(p.castingArtwork, isEmpty);
      expect(m.state.balls.first.speedLeft, greaterThan(0));
      final next = setup(PowerUpKind.speed);
      next.powerUps!.resetForRespawn(next.state.balls.first);
      expect(next.powerUps!.castingArtwork, isEmpty);
    },
  );
  for (final follows in [true, false]) {
    test(
      'Energy Wave cast follows charge and beam only when selected ($follows)',
      () {
        final m = setup(PowerUpKind.energyWave, follows: follows),
            p = m.powerUps!;
        expect(p.castingArtwork, isEmpty); // Equipping is not casting.
        for (var i = 0; i < 180 && p.energyWaveAttacks.isEmpty; i++) {
          p.step();
        }
        expect(p.energyWaveAttacks, hasLength(1));
        expect(p.castingArtwork, hasLength(1));
        for (var i = 0; i < 10; i++) {
          p.step();
        }
        expect(p.energyWaveAttacks, hasLength(1));
        expect(p.castingArtwork.length, follows ? 1 : 0);
        for (var i = 0; i < 300 && p.energyWaveAttacks.isNotEmpty; i++) {
          p.step();
        }
        expect(p.energyWaveAttacks, isEmpty);
        p.step();
        expect(p.castingArtwork, isEmpty);
      },
    );
  }
  test(
    'cast art follows the caster, impact is separate, and hidden effects stay hidden',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        SpriteRegistry.resetForTest();
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawPaint(ui.Paint()..color = const ui.Color(0xff00ff00));
        final picture = recorder.endRecording(),
            sheet = await picture.toImage(32, 16);
        await SpriteRegistry.register(
          SpriteImport.grid(
            sheet: 'a.png',
            width: 32,
            height: 16,
            columns: 2,
            animation: false,
          ),
          sheet,
          idPrefix: 'custom.art',
        );
        final m = setup(PowerUpKind.shadowClone), owner = m.state.balls.first;
        owner.position += const ui.Offset(5, 7);
        final cast = CastCanvas();
        PowerUpPainter.paintCasting(cast, m.state);
        expect(cast.images, [
          same(SpriteRegistry.frame('custom.art.sprite-1')),
        ]);
        expect(cast.targets.single.center, owner.position);
        final hit = CastCanvas();
        PowerUpPainter.paintImpacts(hit, m.state);
        expect(hit.images, isEmpty);
        final hidden = CastCanvas();
        PowerUpPainter.paintCasting(hidden, m.state, showEffects: false);
        expect(hidden.images, isEmpty);
        m.powerUps!.shadowCloneAttacks.clear();
        final ended = CastCanvas();
        PowerUpPainter.paintCasting(ended, m.state);
        expect(ended.images, isEmpty);
        SpriteRegistry.unregister('custom.art');
        sheet.dispose();
        picture.dispose();
      });
    },
  );
}
