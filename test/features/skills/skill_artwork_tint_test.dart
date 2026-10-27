import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

const gold = 0xFFFFD700;
const tuning = PowerUpConfig.defaults;
const balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.red,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.blue,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('replay retains player effect preference and old links use default', () {
    for (final mode in [null, ...EffectRenderMode.values]) {
      final link = ReplayLink(
        seed: 9,
        speedMultiplier: 1,
        contestants: balls,
        effectRenderMode: mode,
      );
      final restored = ReplayLink.fromUri(
        link.toUri(presetIds: {'a', 'b'}),
        presets: balls,
      )!;
      expect(restored.effectRenderMode, mode);
    }
  });
  test('skill effect choice overrides defaults and survives serialization', () {
    final original = SkillLibrary.defaults.builtIn(
      PowerUpKind.boomerang,
      tuning,
    );
    expect(original.usesSpriteEffects(), isTrue);
    expect(original.usesSpriteEffects(globalSprite: false), isFalse);
    final sprite = original.copyWith(effectMode: SkillVisualMode.sprite);
    expect(sprite.usesSpriteEffects(globalSprite: false), isTrue);
    final vector = original.copyWith(effectMode: SkillVisualMode.vector);
    expect(vector.usesSpriteEffects(), isFalse);
    expect(
      SkillDefinition.fromJson(vector.toJson())!.usesSpriteEffects(),
      isFalse,
    );
    expect(
      vector.copyWith(useGlobalEffectVisuals: true).usesSpriteEffects(),
      isTrue,
    );
  });

  test(
    'custom tint survives persistence and replay without recoloring its carrier',
    () {
      final original = SkillLibrary.defaults.builtIn(
        PowerUpKind.boomerang,
        tuning,
      );
      final custom = SkillLibrary.defaults
          .duplicate(original, 'Boom-merang')
          .copyWith(spriteTint: gold);
      final library = SkillLibrary.defaults.withDefinition(custom, tuning);
      final restored = SkillLibrary.fromJson(library.toJson());
      expect(restored.byId(custom.id, tuning)!.spriteTint, gold);
      expect(
        SkillLibrary.decodeReplay(
          library.encodeReplay()!,
        )!.byId(custom.id, tuning)!.spriteTint,
        gold,
      );
      expect(
        restored.builtIn(PowerUpKind.boomerang, tuning).spriteTint,
        0xFFFFFFFF,
      );
      final match = MatchSimulationController(
        balls,
        arenaRadius: 100,
        seed: 1,
        mode: MatchMode.arsenal,
        lookAhead: false,
        skillLibrary: restored,
      );
      expect(
        match.powerUps!.artworkTint(PowerUpKind.boomerang, skillId: custom.id),
        gold,
      );
      expect(match.powerUps!.artworkTint(PowerUpKind.boomerang), 0xFFFFFFFF);
      final legacy = Map<String, Object?>.from(custom.toJson())
        ..remove('sprite_tint');
      expect(SkillDefinition.fromJson(legacy)!.spriteTint, 0xFFFFFFFF);
    },
  );

  for (final resource in ['pickup', 'projectile', 'equipped', 'explosion']) {
    test('$resource renders gold with shading and no tint leakage', () async {
      await PowerUpSprites.load();
      Future<List<int>> render(int tint) async {
        final skill = SkillLibrary.defaults
            .builtIn(PowerUpKind.boomerang, tuning)
            .copyWith(spriteTint: tint);
        final c = MatchSimulationController(
          balls,
          arenaRadius: 100,
          seed: 1,
          mode: MatchMode.arsenal,
          lookAhead: false,
          skillLibrary: SkillLibrary.defaults.withDefinition(skill, tuning),
        );
        final p = c.powerUps!;
        final ball = c.state.balls.first..position = Offset.zero;
        if (resource == 'pickup') {
          p.field.add(
            FieldPowerUp(
              kind: PowerUpKind.boomerang,
              position: Offset.zero,
              spawnStep: 0,
            ),
          );
        }
        if (resource == 'projectile') {
          p.projectiles.add(
            Projectile(
              owner: ball,
              kind: PowerUpKind.boomerang,
              position: Offset.zero,
              velocity: const Offset(100, 0),
            ),
          );
        }
        if (resource == 'explosion') {
          p.explosions.add(
            Explosion(
              kind: PowerUpKind.boomerang,
              skillId: skill.id,
              position: Offset.zero,
              radius: 24,
            ),
          );
        }
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..translate(64, 64);
        if (resource == 'equipped') {
          ball.held = PowerUpKind.boomerang;
          PowerUpPainter.paintBallEffects(
            canvas,
            ball,
            artworkTint: (kind, slot) => p.artworkTint(kind, ball: ball),
          );
        } else {
          PowerUpPainter.paint(
            canvas,
            c.state,
            100,
            whitePickupBackgrounds: false,
          );
        }
        // This white square must stay white after the tinted resource was drawn.
        canvas.drawRect(
          const Rect.fromLTWH(-64, -64, 4, 4),
          Paint()..color = Colors.white,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(128, 128);
        if (const bool.fromEnvironment('TINT_PREVIEW')) {
          await File(
            'build/tint-$resource-${tint == gold ? "gold" : "original"}.png',
          ).writeAsBytes(
            (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
        }
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(bytes.take(4), [255, 255, 255, 255]);
        final totals = [0, 0, 0, 0];
        for (var y = 8; y < 128; y++) {
          for (var x = 8; x < 128; x++) {
            final i = (y * 128 + x) * 4;
            if (bytes[i + 3] == 0) continue;
            for (var channel = 0; channel < 3; channel++) {
              totals[channel] += bytes[i + channel];
            }
            totals[3]++;
          }
        }
        image.dispose();
        picture.dispose();
        return totals;
      }

      final original = await render(0xFFFFFFFF);
      final tinted = await render(gold);
      expect(tinted[3], greaterThan(0));
      expect(
        tinted[3],
        original[3],
        reason: 'Tint preserves the alpha silhouette',
      );
      expect(tinted[0], greaterThan(tinted[1]));
      expect(tinted[1], greaterThan(tinted[2]));
      expect(tinted[2], 0, reason: 'Gold removes blue from the source artwork');
    });
  }
}
