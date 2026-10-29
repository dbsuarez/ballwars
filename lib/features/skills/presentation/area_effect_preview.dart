import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../arena_simulation/presentation/power_up_painter.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/skill_library.dart';

/// A quiet, unstepped scene using the real zone/explosion painter. Editing art
/// cannot cause damage or persist changes; the markers give a size reference.
class AreaEffectPreview extends StatelessWidget {
  const AreaEffectPreview({
    super.key,
    required this.skill,
    required this.library,
    required this.radiusRatio,
  });
  final SkillDefinition skill;
  final SkillLibrary library;
  final double radiusRatio;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: SpriteRegistry.revision,
    builder: (_, _, _) => SizedBox(
      width: double.infinity,
      height: 180,
      child: CustomPaint(painter: _AreaPreview(skill, library, radiusRatio)),
    ),
  );
}

class _AreaPreview extends CustomPainter {
  _AreaPreview(this.skill, this.library, this.ratio);
  final SkillDefinition skill;
  final SkillLibrary library;
  final double ratio;
  @override
  void paint(Canvas canvas, Size size) {
    final match = MatchSimulationController(
      const [
        CustomBall(
          id: 'area-a',
          name: 'A',
          primaryColor: Colors.blue,
          glowColor: Colors.blue,
        ),
        CustomBall(
          id: 'area-b',
          name: 'B',
          primaryColor: Colors.red,
          glowColor: Colors.red,
        ),
      ],
      arenaRadius: 180,
      seed: 1,
      mode: MatchMode.arsenal,
      lookAhead: false,
      automaticSpeedUp: false,
      skillLibrary: library.withDefinition(skill, PowerUpConfig.defaults),
    );
    final p = match.powerUps!, radius = 180 * ratio;
    final owner = match.state.balls.first;
    if (!skill.isComposed && skill.baseKind == PowerUpKind.molotov) {
      p.burningZones.add(
        BurningZone(owner: owner, position: Offset.zero, radius: radius),
      );
    } else if (areaArtworkRole(skill) == SkillVisualRole.explosion) {
      p.explosions.add(
        Explosion(
          position: Offset.zero,
          radius: radius,
          kind: skill.baseKind,
          skillId: skill.id,
        )..age = 6,
      );
    } else {
      p.persistentEffects.area(owner, skill, Offset.zero, radius);
    }
    p.persistentEffects.sync();
    final art = library.resolveVisual(skill, areaArtworkRole(skill));
    final image = art == null ? null : SpriteRegistry.frame(art.spriteId);
    final artScale =
        (art?.scale ?? library.effectDisplayScaleFor(skill)) *
        (image == null ? 1 : SpriteRegistry.imageScale(image));
    final offsets =
        math.max(art?.offsetX.abs() ?? 0, art?.offsetY.abs() ?? 0) *
        match.state.balls.first.radius;
    final extent = math.max(radius + 27, radius * artScale + offsets);
    final scale = math.min(size.width / 2 - 12, 76.0) / math.max(48, extent);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.drawCircle(
      Offset.zero,
      180,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke,
    );
    PowerUpPainter.paint(canvas, match.state, 180);
    for (final entry in [
      (Offset(-radius * .65, 0), Colors.blue),
      (Offset(radius + 18, 0), Colors.redAccent),
    ]) {
      canvas.drawCircle(entry.$1, 9, Paint()..color = entry.$2);
      for (final x in [-3.0, 3.0]) {
        canvas.drawCircle(
          entry.$1 + Offset(x, -2),
          2,
          Paint()..color = Colors.white,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AreaPreview old) => true;
}
