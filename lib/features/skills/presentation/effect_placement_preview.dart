import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/sprites/sprite_registry.dart';
import '../domain/skill_visual_effect.dart';
import 'skill_effect_renderer.dart';
import 'skill_artwork_tint.dart';

/// Uses the game's attachment and transform renderer, not a mock transform.
class EffectPlacementPreview extends StatelessWidget {
  const EffectPlacementPreview({
    super.key,
    required this.effect,
    required this.role,
    this.progress = 0,
    this.height = 150,
  });
  final ResolvedSkillEffect? effect;
  final SkillVisualRole role;
  final double progress;
  final double height;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (final right in [true, false])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    height: height,
                    child: CustomPaint(
                      painter: _PlacementPainter(effect, role, right, progress),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const Text(
        'Right / Left | cross = position | auto-fit',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11),
      ),
      if (effect == null) const Text('Choose artwork to see its placement.'),
    ],
  );
}

class _PlacementPainter extends CustomPainter {
  _PlacementPainter(this.effect, this.role, this.right, this.progress);
  final ResolvedSkillEffect? effect;
  final SkillVisualRole role;
  final bool right;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        direction = Offset(right ? 1 : -1, 0);
    final frame = effect == null
        ? null
        : SpriteRegistry.frame(effect!.spriteId);
    final anchor = effect == null
        ? SpriteRegistry.center
        : SpriteRegistry.anchor(effect!.spriteId);
    final meta = frame == null ? 1 : SpriteRegistry.imageScale(frame);
    final rotation = (effect?.rotationDegrees ?? 0) * math.pi / 180;
    final corner =
        2 *
        math.max(
          math.max(anchor.dx, 1 - anchor.dx),
          math.max(anchor.dy, 1 - anchor.dy),
        );
    final half =
        (effect?.scale ?? 1) *
        1.4 *
        meta *
        corner *
        (math.cos(rotation).abs() + math.sin(rotation).abs());
    final hand =
        effect?.attachment == EffectAttachment.hand ||
            (effect?.attachment == EffectAttachment.automatic &&
                role == SkillVisualRole.muzzle)
        ? 1.1
        : 0.0;
    final horizontal = math.max(
      1.2,
      (hand + (effect?.offsetX ?? 0)).abs() + half,
    );
    final vertical = math.max(1.2, (effect?.offsetY ?? 0).abs() + half);
    final r = math.min(
      32.0,
      math.min(
        (size.width / 2 - 8) / horizontal,
        (size.height / 2 - 8) / vertical,
      ),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      Offset(8, center.dy),
      Offset(size.width - 8, center.dy),
      Paint()..color = Colors.white12,
    );
    canvas.drawCircle(center, r, Paint()..color = const Color(0xff526b8a));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke,
    );
    for (final dx in [-r * .33, r * .33]) {
      final eye = center + Offset(dx, -r * .2);
      canvas.drawCircle(eye, r * .2, Paint()..color = Colors.white);
      canvas.drawCircle(
        eye + direction * 1.5,
        2,
        Paint()..color = Colors.black,
      );
    }
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(
        center + Offset(sign * r * .95, r * .5),
        5,
        Paint()..color = Colors.white,
      );
    }
    final e = effect;
    if (e != null) {
      final point = role == SkillVisualRole.muzzle
          ? center + direction * r
          : center;
      final attached = SkillEffectRenderer.attachment(
        e,
        role,
        point,
        owner: center,
        target: center,
        direction: direction,
        radius: r,
      );
      final steps = ((e.durationSeconds ?? 1) * 60).round().clamp(1, 600);
      SkillArtworkTint.begin(canvas, e.tint);
      SkillEffectRenderer.paint(
        canvas,
        e,
        attached,
        r * 1.4,
        (progress *
                (e.playback == EffectPlayback.once
                    ? steps - 1
                    : math.max(
                        1,
                        SpriteRegistry.frameCount(e.spriteId) *
                                SpriteRegistry.stepsPerFrame(e.spriteId) -
                            1,
                      )))
            .round(),
        steps,
        direction: direction,
        unitRadius: r,
      );
      SkillArtworkTint.end(canvas);
      final unit = direction;
      final cross =
          attached +
          unit * e.offsetX * r +
          Offset(-unit.dy, unit.dx) * e.offsetY * r;
      final pen = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 1;
      canvas.drawLine(
        cross - const Offset(5, 0),
        cross + const Offset(5, 0),
        pen,
      );
      canvas.drawLine(
        cross - const Offset(0, 5),
        cross + const Offset(0, 5),
        pen,
      );
      if (!SpriteRegistry.has(e.spriteId)) {
        canvas.drawCircle(center, 4, Paint()..color = Colors.orangeAccent);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlacementPainter oldDelegate) => true;
}
