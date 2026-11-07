import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

class _PortalCanvas extends Fake implements Canvas {
  final ovals = <Rect>[];
  final sprites = <Rect>[];
  @override
  void drawOval(Rect rect, Paint paint) => ovals.add(rect);
  @override
  void drawImageRect(ui.Image image, Rect source, Rect target, Paint paint) =>
      sprites.add(target);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MatchSimulationController _match(double scale) {
  final portal = SkillLibrary.defaults
      .builtIn(PowerUpKind.portal, PowerUpConfig.defaults)
      .copyWith(effectDisplayScale: scale);
  return MatchSimulationController(
    const [
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
    ],
    arenaRadius: 260,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: SkillLibrary.defaults.withDefinition(
      portal,
      PowerUpConfig.defaults,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(PowerUpSprites.load);
  });
  for (final mode in EffectRenderMode.values) {
    test('portal entry and exit both follow artwork scale in ${mode.name}', () {
      final sizes = <double, List<Size>>{};
      for (final scale in [1.0, 2.0]) {
        final match = _match(scale);
        match.powerUps!.portalFlashes.add(
          PortalFlash(from: const Offset(-100, 0), to: const Offset(100, 0)),
        );
        final canvas = _PortalCanvas();
        PowerUpPainter.paint(
          canvas,
          match.state,
          260,
          explosionRenderMode: mode,
        );
        expect(canvas.ovals, hasLength(2));
        expect(canvas.ovals[0].size, canvas.ovals[1].size);
        if (mode == EffectRenderMode.sprite) {
          expect(canvas.sprites, hasLength(2));
          expect(canvas.sprites[0].size, canvas.sprites[1].size);
        }
        sizes[scale] = [
          ...canvas.ovals,
          ...canvas.sprites,
        ].map((rect) => rect.size).toList();
      }
      for (var i = 0; i < sizes[1]!.length; i++) {
        expect(sizes[2]![i].width, closeTo(sizes[1]![i].width * 2, 1e-8));
        expect(sizes[2]![i].height, closeTo(sizes[1]![i].height * 2, 1e-8));
      }
    });
  }
  test('portal sizing does not change Swap Cannon bursts', () {
    final sizes = <List<Size>>[];
    for (final scale in [1.0, 2.0]) {
      final match = _match(scale);
      match.powerUps!.portalFlashes.add(
        PortalFlash(from: Offset.zero, to: const Offset(100, 0), swap: true),
      );
      final canvas = _PortalCanvas();
      PowerUpPainter.paint(canvas, match.state, 260);
      sizes.add(
        [...canvas.ovals, ...canvas.sprites].map((rect) => rect.size).toList(),
      );
    }
    expect(sizes[0], sizes[1]);
  });
}
