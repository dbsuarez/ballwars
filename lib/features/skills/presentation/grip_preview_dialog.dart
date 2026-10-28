import 'package:flutter/material.dart';

import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arena_simulation/presentation/ball_face_expression.dart';
import '../../arena_simulation/presentation/power_up_painter.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/skill_library.dart';

/// A held weapon's grip: [inset] pulls it in along the aim, [side] moves it
/// across the aim (both in ball radii) and [rotation] turns the sprite
/// (degrees).
@immutable
class GripValues {
  const GripValues({
    this.inset = 0,
    this.side = 0,
    this.rotation = 0,
    this.facing = SkillHeldFacing.automatic,
  });

  final double inset;
  final double side;
  final double rotation;
  final SkillHeldFacing facing;

  GripValues copyWith({
    double? inset,
    double? side,
    double? rotation,
    SkillHeldFacing? facing,
  }) => GripValues(
    inset: inset ?? this.inset,
    side: side ?? this.side,
    rotation: rotation ?? this.rotation,
    facing: facing ?? this.facing,
  );
}

/// A small popup showing a ball holding [kind] with the real held-weapon
/// painter, facing right and left so the mirroring is visible, with live
/// sliders for the three grip values. Done returns them; Cancel returns null.
class GripPreviewDialog extends StatefulWidget {
  const GripPreviewDialog({
    super.key,
    required this.kind,
    required this.grip,
    this.artwork,
    this.tint = 0xFFFFFFFF,
    this.useSprite = true,
    this.displayScale = 1,
    this.spriteId,
  });

  final PowerUpKind kind;
  final PowerUpKind? artwork;
  final int tint;
  final bool useSprite;
  final double displayScale;
  final GripValues grip;
  final String? spriteId;

  static Future<GripValues?> show(
    BuildContext context, {
    required PowerUpKind kind,
    required GripValues grip,
    PowerUpKind? artwork,
    int tint = 0xFFFFFFFF,
    bool useSprite = true,
    double displayScale = 1,
    String? spriteId,
  }) => showDialog<GripValues>(
    context: context,
    builder: (_) => GripPreviewDialog(
      kind: kind,
      grip: grip,
      artwork: artwork,
      tint: tint,
      useSprite: useSprite,
      displayScale: displayScale,
      spriteId: spriteId,
    ),
  );

  @override
  State<GripPreviewDialog> createState() => _GripPreviewDialogState();
}

class _GripPreviewDialogState extends State<GripPreviewDialog> {
  late GripValues _grip = GripValues(
    inset: widget.grip.inset.clamp(-1.5, 1.5),
    side: widget.grip.side.clamp(-1.5, 1.5),
    rotation: widget.grip.rotation.clamp(-180.0, 180.0),
    facing: widget.grip.facing,
  );

  Widget _slider(
    String key,
    String label,
    double value,
    double min,
    double max,
    String unit,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: Slider(
            key: ValueKey('grip-preview-$key'),
            value: value,
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '${value.toStringAsFixed(unit == 'deg' ? 0 : 2)} $unit',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget view(String key, bool facingRight, bool loaded) => Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            key: ValueKey('grip-preview-$key'),
            painter: _GripPreviewPainter(
              kind: widget.kind,
              artwork: widget.artwork ?? widget.kind,
              tint: widget.tint,
              useSprite: widget.useSprite,
              displayScale: widget.displayScale,
              grip: _grip,
              facingRight: facingRight,
              ballColor: colors.primary,
              spritesLoaded: loaded,
              spriteId: widget.spriteId,
            ),
          ),
        ),
      ),
    );
    return Dialog(
      child: ConstrainedBox(
        key: const ValueKey('grip-preview-dialog'),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Grip preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              // Rebuilds once the sprites have loaded; until then the
              // painter draws the glyph fallback.
              FutureBuilder<void>(
                future: PowerUpSprites.load(),
                builder: (_, snapshot) {
                  final loaded =
                      snapshot.connectionState == ConnectionState.done;
                  return Row(
                    children: [
                      view('right', true, loaded),
                      const SizedBox(width: 12),
                      view('left', false, loaded),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              _slider(
                'inset',
                'Forward/back',
                _grip.inset,
                -1.5,
                1.5,
                'r',
                (v) => _grip = _grip.copyWith(inset: v),
              ),
              _slider(
                'side',
                'Sideways',
                _grip.side,
                -1.5,
                1.5,
                'r',
                (v) => _grip = _grip.copyWith(side: v),
              ),
              _slider(
                'rotation',
                'Rotation',
                _grip.rotation,
                -180,
                180,
                'deg',
                (v) => _grip = _grip.copyWith(rotation: v),
              ),
              Row(
                children: [
                  const SizedBox(width: 100, child: Text('Facing')),
                  Expanded(
                    child: DropdownButton<SkillHeldFacing>(
                      key: const ValueKey('grip-preview-facing'),
                      isExpanded: true,
                      value: _grip.facing,
                      items: [
                        for (final mode in SkillHeldFacing.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                      ],
                      onChanged: (mode) =>
                          setState(() => _grip = _grip.copyWith(facing: mode)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('grip-preview-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('grip-preview-done'),
                    onPressed: () => Navigator.of(context).pop(_grip),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GripPreviewPainter extends CustomPainter {
  const _GripPreviewPainter({
    required this.kind,
    required this.artwork,
    required this.tint,
    required this.useSprite,
    required this.displayScale,
    required this.grip,
    required this.facingRight,
    required this.ballColor,
    required this.spritesLoaded,
    this.spriteId,
  });

  final PowerUpKind kind;
  final PowerUpKind artwork;
  final int tint;
  final bool useSprite;
  final double displayScale;
  final GripValues grip;
  final bool facingRight;
  final Color ballColor;

  /// Only repaints the views once the sprites arrive.
  final bool spritesLoaded;
  final String? spriteId;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.16;
    // Leave room in front of the ball for the weapon.
    final center = Offset(
      size.width * (facingRight ? 0.36 : 0.64),
      size.height / 2,
    );
    final ball = SimulationBall(
      config: CustomBall(
        id: 'grip-preview',
        name: 'Preview',
        primaryColor: ballColor,
        glowColor: ballColor,
      ),
      position: center,
      velocity: Offset(facingRight ? 1 : -1, 0),
      radius: radius,
      lineCount: 0,
    );
    if (kind.isWeapon) ball.equipWeapon(kind, dualWield: false);
    canvas.drawCircle(center, radius, Paint()..color = ballColor);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF111114),
    );
    PowerUpPainter.paintBallEffects(
      canvas,
      ball,
      useWeaponSprite: (_, _) => useSprite,
      artworkTint: (_, _) => tint,
      artworkKind: (_, _) => artwork,
      iconSpriteId: (_, _) => spriteId,
      weaponDisplayScale: (_, _) => displayScale,
      weaponGripInset: (_, _) => grip.inset,
      weaponGripSide: (_, _) => grip.side,
      weaponGripRotation: (_, _) => grip.rotation,
      heldFacing: (_, _) => grip.facing,
    );
    paintHands(canvas, ball);
    if (kind.isWeapon) {
      // Crosshair at the (fixed) gripping hand: slide the hilt onto it.
      final mark = gripHandPosition(ball);
      final arm = radius * 0.3;
      canvas.drawLine(
        mark - Offset(arm, 0),
        mark + Offset(arm, 0),
        _markerPaint,
      );
      canvas.drawLine(
        mark - Offset(0, arm),
        mark + Offset(0, arm),
        _markerPaint,
      );
    }
  }

  static final Paint _markerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFFE53935);

  @override
  bool shouldRepaint(_GripPreviewPainter old) =>
      old.grip.inset != grip.inset ||
      old.grip.side != grip.side ||
      old.grip.rotation != grip.rotation ||
      old.grip.facing != grip.facing ||
      old.kind != kind ||
      old.artwork != artwork ||
      old.tint != tint ||
      old.useSprite != useSprite ||
      old.displayScale != displayScale ||
      old.facingRight != facingRight ||
      old.ballColor != ballColor ||
      old.spritesLoaded != spritesLoaded ||
      old.spriteId != spriteId;
}
