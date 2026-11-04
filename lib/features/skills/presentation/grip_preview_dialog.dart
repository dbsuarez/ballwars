import 'package:flutter/material.dart';

import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arena_simulation/presentation/ball_face_expression.dart';
import '../../arena_simulation/presentation/power_up_painter.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/skill_library.dart';
import '../../sprites/presentation/sprites_screen.dart';

/// A held weapon's grip: [inset] pulls it in along the aim, [side] moves it
/// across the aim (both in ball radii) and [rotation] turns the sprite
/// (degrees).
@immutable
class GripValues {
  static const Object _unchanged = Object();
  const GripValues({
    this.inset = 0,
    this.side = 0,
    this.rotation = 0,
    this.facing = SkillHeldFacing.automatic,
    this.heldAttachment = 'right',
    this.effectAttachment = 'both',
    this.heldOffsetX = 0,
    this.heldOffsetY = 0,
    this.effectOffsetX = 0,
    this.effectOffsetY = 0,
    this.pickupScale = 1,
    this.attackAnimation,
    this.attackRepeatCount = 1,
    this.attackDurationSteps = 30,
  });

  final double inset;
  final double side;
  final double rotation;
  final SkillHeldFacing facing;
  final String heldAttachment;
  final String effectAttachment;
  final double heldOffsetX, heldOffsetY, effectOffsetX, effectOffsetY;
  final double pickupScale;
  final HeldAttackAnimation? attackAnimation;
  final int attackRepeatCount;
  final int attackDurationSteps;

  /// Moves the selected layer by a screen-space drag expressed in ball radii.
  /// Both layers retain independent offsets; values stay within editor limits.
  GripValues movedBy(double dx, double dy, {required bool effect}) {
    if (!dx.isFinite || !dy.isFinite) return this;
    return effect
        ? copyWith(
            effectOffsetX: (effectOffsetX + dx).clamp(-1.5, 1.5),
            effectOffsetY: (effectOffsetY + dy).clamp(-1.5, 1.5),
          )
        : copyWith(
            heldOffsetX: (heldOffsetX + dx).clamp(-1.5, 1.5),
            heldOffsetY: (heldOffsetY + dy).clamp(-1.5, 1.5),
          );
  }

  GripValues copyWith({
    Object? attackAnimation = _unchanged,
    int? attackRepeatCount,
    int? attackDurationSteps,
    double? inset,
    double? side,
    double? rotation,
    SkillHeldFacing? facing,
    String? heldAttachment, effectAttachment,
    double? heldOffsetX, heldOffsetY, effectOffsetX, effectOffsetY, pickupScale,
  }) => GripValues(
    attackAnimation: identical(attackAnimation, _unchanged)
        ? this.attackAnimation : attackAnimation as HeldAttackAnimation?,
    attackRepeatCount: (attackRepeatCount ?? this.attackRepeatCount).clamp(1, 5),
    attackDurationSteps: (attackDurationSteps ?? this.attackDurationSteps).clamp(12, 90),
    inset: inset ?? this.inset,
    side: side ?? this.side,
    rotation: rotation ?? this.rotation,
    facing: facing ?? this.facing,
    heldAttachment: heldAttachment ?? this.heldAttachment,
    effectAttachment: effectAttachment ?? this.effectAttachment,
    heldOffsetX: heldOffsetX ?? this.heldOffsetX,
    heldOffsetY: heldOffsetY ?? this.heldOffsetY,
    effectOffsetX: effectOffsetX ?? this.effectOffsetX,
    effectOffsetY: effectOffsetY ?? this.effectOffsetY,
    pickupScale: pickupScale ?? this.pickupScale,
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
    this.skill,
    this.pickupSpriteId,
    this.pickupScale = 1,
    this.projectileSpriteId,
    this.impactSpriteId,
  });

  final PowerUpKind kind;
  final PowerUpKind? artwork;
  final int tint;
  final bool useSprite;
  final double displayScale;
  final GripValues grip;
  final String? spriteId;
  final SkillDefinition? skill;
  final String? pickupSpriteId;
  final double pickupScale;
  final String? projectileSpriteId;
  final String? impactSpriteId;

  static Future<GripValues?> show(
    BuildContext context, {
    required PowerUpKind kind,
    required GripValues grip,
    PowerUpKind? artwork,
    int tint = 0xFFFFFFFF,
    bool useSprite = true,
    double displayScale = 1,
    String? spriteId,
    SkillDefinition? skill,
    String? pickupSpriteId,
    double pickupScale = 1,
    String? projectileSpriteId,
    String? impactSpriteId,
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
      skill: skill,
      pickupSpriteId: pickupSpriteId,
      pickupScale: pickupScale,
      projectileSpriteId: projectileSpriteId,
      impactSpriteId: impactSpriteId,
    ),
  );

  @override
  State<GripPreviewDialog> createState() => _GripPreviewDialogState();
}

class _GripPreviewDialogState extends State<GripPreviewDialog> {
  // Dragging changes the same unsaved offset values as the sliders. A drag is
  // measured in ball radii, not screen pixels, so it behaves at any viewport size.
  bool _dragEffect = false;
  double _attackFrame = 0;

  void _dragArtwork(DragUpdateDetails details, Size previewSize) {
    final radius = previewSize.shortestSide * 0.16;
    if (radius <= 0) return;
    final dx = details.delta.dx / radius;
    final dy = details.delta.dy / radius;
    setState(() => _grip = _grip.movedBy(dx, dy, effect: _dragEffect));
  }

  late GripValues _grip = GripValues(
    inset: widget.grip.inset.clamp(-1.5, 1.5),
    side: widget.grip.side.clamp(-1.5, 1.5),
    rotation: widget.grip.rotation.clamp(-180.0, 180.0),
    facing: widget.grip.facing,
    heldAttachment: widget.grip.heldAttachment,
    effectAttachment: widget.grip.effectAttachment,
    heldOffsetX: widget.grip.heldOffsetX.clamp(-1.5, 1.5),
    heldOffsetY: widget.grip.heldOffsetY.clamp(-1.5, 1.5),
    effectOffsetX: widget.grip.effectOffsetX.clamp(-1.5, 1.5),
    effectOffsetY: widget.grip.effectOffsetY.clamp(-1.5, 1.5),
    pickupScale: widget.pickupScale.clamp(0.25, 3),
    attackAnimation: widget.grip.attackAnimation,
    attackRepeatCount: widget.grip.attackRepeatCount.clamp(1, 5),
    attackDurationSteps: widget.grip.attackDurationSteps.clamp(12, 90),
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
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              key: ValueKey('grip-preview-drag-$key'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => _dragArtwork(
                details,
                Size(constraints.maxWidth, constraints.maxHeight),
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
              attackFrame: _attackFrame,
              facingRight: facingRight,
              ballColor: colors.primary,
              spritesLoaded: loaded,
              spriteId: widget.spriteId,
              skill: widget.skill,
            ),
              ),
            ),
          ),
        ),
      ),
    );
    return Dialog(
      child: ConstrainedBox(
        key: const ValueKey('grip-preview-dialog'),
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Grip preview',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            // Both orientations remain visible while editing settings below.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.24)
                    .clamp(96.0, 180.0),
                child: Column(
                  children: [
              // Rebuilds once the sprites have loaded; until then the
              // painter draws the glyph fallback.
              Expanded(child: FutureBuilder<void>(
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
              )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('grip-preview-settings-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              if (widget.kind.isWeapon) ...[
                DropdownButtonFormField<HeldAttackAnimation?>(
                  key: const ValueKey('grip-preview-attack-animation'),
                  initialValue: _grip.attackAnimation,
                  decoration: const InputDecoration(labelText: 'Held attack animation'),
                  items: const [
                    DropdownMenuItem<HeldAttackAnimation?>(value: null, child: Text('Legacy')),
                    DropdownMenuItem<HeldAttackAnimation?>(value: HeldAttackAnimation.slash, child: Text('Slash / Swing')),
                    DropdownMenuItem<HeldAttackAnimation?>(value: HeldAttackAnimation.thrust, child: Text('Thrust')),
                    DropdownMenuItem<HeldAttackAnimation?>(value: HeldAttackAnimation.none, child: Text('None')),
                  ],
                  onChanged: (value) => setState(() => _grip = _grip.copyWith(attackAnimation: value)),
                ),
                DropdownButtonFormField<int>(
                  key: const ValueKey('grip-preview-attack-repeats'),
                  initialValue: _grip.attackRepeatCount,
                  decoration: const InputDecoration(labelText: 'Attack repeats (visual only)'),
                  items: [for (var count = 1; count <= 5; count++)
                    DropdownMenuItem(value: count, child: Text('$count'))],
                  onChanged: (value) => setState(() =>
                      _grip = _grip.copyWith(attackRepeatCount: value ?? 1)),
                ),
                DropdownButtonFormField<int>(
                  key: const ValueKey('grip-preview-attack-duration'),
                  initialValue: _grip.attackDurationSteps,
                  decoration: const InputDecoration(labelText: 'Attack duration (simulation steps)'),
                  items: [for (var steps = 12; steps <= 90; steps++)
                    DropdownMenuItem(value: steps, child: Text('$steps steps'))],
                  onChanged: (value) => setState(() =>
                      _grip = _grip.copyWith(attackDurationSteps: value ?? 30)),
                ),
                _slider('attack-frame', 'Attack frame', _attackFrame, 0, 1, '',
                    (v) => _attackFrame = v),
              ],
              const SizedBox(height: 12),
              if (widget.skill != null) ...[
                const SizedBox(height: 8),
                const Text('Drag the preview to adjust offsets. Select which artwork to move.'),
                SegmentedButton<bool>(
                  key: const ValueKey('grip-preview-drag-target'),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Held sprite')),
                    ButtonSegment(value: true, label: Text('Hand effect')),
                  ],
                  selected: {_dragEffect},
                  onSelectionChanged: (selected) =>
                      setState(() => _dragEffect = selected.first),
                ),
                const SizedBox(height: 8),
                const Text('Pickup artwork', style: TextStyle(fontWeight: FontWeight.bold)),
                Center(child: GestureDetector(
                  key: const ValueKey('grip-preview-pickup-drag-scale'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() => _grip =
                      _grip.copyWith(pickupScale:
                        (_grip.pickupScale + details.delta.dx / 80)
                            .clamp(.25, 3.0))),
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Center(child: SizedBox(
                      width: (48 * _grip.pickupScale).clamp(12.0, 144.0),
                      height: (48 * _grip.pickupScale).clamp(12.0, 144.0),
                      child: FittedBox(child: SpriteThumbnail(
                        id: widget.pickupSpriteId ?? widget.spriteId,
                      )),
                    )),
                  ),
                )),
                const Text('Drag pickup horizontally to resize, or use the slider.',
                    textAlign: TextAlign.center),
                _slider('pickup-scale', 'Pickup size', _grip.pickupScale, 0.25, 3, 'x',
                    (v) => _grip = _grip.copyWith(pickupScale: v)),
                const SizedBox(height: 8),
                const Text('Other artwork (animated when frames are available)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final item in [
                      ('Projectile', widget.projectileSpriteId ??
                          PowerUpSprites.projectileArtworkId(widget.kind)),
                      ('Impact', widget.impactSpriteId),
                    ])
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item.$1, textAlign: TextAlign.center),
                            SpriteThumbnail(id: item.$2, size: 72),
                            Text(
                              item.$2 == null ? 'Built-in / no sprite' : 'Sprite animation',
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const Text('Changes remain unsaved until Done and editor Save.'),
                for (final entry in [
                  ('Held sprite', _grip.heldAttachment, true),
                  ('Hand effect', _grip.effectAttachment, false),
                ])
                  DropdownButtonFormField<String>(
                    key: ValueKey(entry.$3 ? 'grip-preview-held-attachment' : 'grip-preview-effect-attachment'),
                    initialValue: entry.$2,
                    decoration: InputDecoration(labelText: entry.$1),
                    items: const [
                      DropdownMenuItem(value: 'left', child: Text('Left hand')),
                      DropdownMenuItem(value: 'right', child: Text('Right hand')),
                      DropdownMenuItem(value: 'both', child: Text('Both hands')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _grip = entry.$3
                              ? _grip.copyWith(heldAttachment: value)
                              : _grip.copyWith(effectAttachment: value);
                        });
                      }
                    },
                  ),
                _slider('held-x', 'Held X', _grip.heldOffsetX, -1.5, 1.5, 'r',
                    (v) => _grip = _grip.copyWith(heldOffsetX: v)),
                _slider('held-y', 'Held Y', _grip.heldOffsetY, -1.5, 1.5, 'r',
                    (v) => _grip = _grip.copyWith(heldOffsetY: v)),
                _slider('effect-x', 'Effect X', _grip.effectOffsetX, -1.5, 1.5, 'r',
                    (v) => _grip = _grip.copyWith(effectOffsetX: v)),
                _slider('effect-y', 'Effect Y', _grip.effectOffsetY, -1.5, 1.5, 'r',
                    (v) => _grip = _grip.copyWith(effectOffsetY: v)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('grip-preview-reset-offsets'),
                    onPressed: () => setState(() => _grip = _grip.copyWith(
                      heldOffsetX: 0, heldOffsetY: 0,
                      effectOffsetX: 0, effectOffsetY: 0,
                    )),
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset offsets'),
                  ),
                ),
              ],
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
          ],
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
    required this.attackFrame,
    required this.facingRight,
    required this.ballColor,
    required this.spritesLoaded,
    this.spriteId,
    this.skill,
  });

  final PowerUpKind kind;
  final PowerUpKind artwork;
  final int tint;
  final bool useSprite;
  final double displayScale;
  final GripValues grip;
  final double attackFrame;
  final bool facingRight;
  final Color ballColor;

  /// Only repaints the views once the sprites arrive.
  final bool spritesLoaded;
  final String? spriteId;
  final SkillDefinition? skill;

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
      firedWeaponHoldLeft: (_, _) => attackFrame == 0 ? 0 :
          (grip.attackDurationSteps * (1 - attackFrame)).round()
              .clamp(1, grip.attackDurationSteps),
      heldAttackDurationSteps: (_, _) => grip.attackDurationSteps,
      heldAttackAnimation: (_, _) => grip.attackAnimation,
      heldAttackRepeatCount: (_, _) => grip.attackRepeatCount,
      heldFacing: (_, _) => grip.facing,
      handArtworkSettings: (_) => skill?.copyWith(
        heldAttachment: grip.heldAttachment,
        effectAttachment: grip.effectAttachment,
        heldOffsetX: grip.heldOffsetX,
        heldOffsetY: grip.heldOffsetY,
        effectOffsetX: grip.effectOffsetX,
        effectOffsetY: grip.effectOffsetY,
      ),
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
      old.spriteId != spriteId ||
      old.skill != skill ||
      old.grip.heldAttachment != grip.heldAttachment ||
      old.grip.effectAttachment != grip.effectAttachment ||
      old.grip.heldOffsetX != grip.heldOffsetX ||
      old.grip.heldOffsetY != grip.heldOffsetY ||
      old.grip.effectOffsetX != grip.effectOffsetX ||
      old.grip.effectOffsetY != grip.effectOffsetY;
}
