import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/combat_diagnostics_overlay.dart';
import 'package:ballwars/features/skills/application/skill_demo_controller.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('diagnostics painting is read-only for balls and target selection', () {
    final demo = SkillDemoController(
      skill: SkillLibrary.defaults.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults),
      library: SkillLibrary.defaults,
      tuning: PowerUpConfig.defaults,
    );
    demo.centerObstacle = CenterObstacle.square;
    demo.reset();
    final owner = demo.match.state.balls.first;
    final target = demo.match.state.balls.last;
    final priorPosition = owner.position;
    final priorTarget = owner.aimTarget;
    final priorStep = demo.match.stepCount;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    CombatDiagnosticsOverlay(demo.match).paint(canvas, const Size(320, 320));
    recorder.endRecording().dispose();
    expect(owner.position, priorPosition);
    expect(owner.aimTarget, same(priorTarget));
    expect(owner.aimTarget, same(target));
    expect(demo.match.stepCount, priorStep);
  });
}
