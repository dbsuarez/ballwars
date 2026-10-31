import 'package:flutter/material.dart';
import '../domain/match_config.dart';

/// Editable preview of the arena's outer boundary and hollow obstacle.
/// This editor shares the same shape and obstacle values used by physics.
class ArenaGeometrySelection {
  const ArenaGeometrySelection(this.shape, this.obstacle, this.scale);
  final ArenaShape shape;
  final CenterObstacle obstacle;
  final double scale;
}

Future<ArenaGeometrySelection?> showArenaGeometryEditor(
  BuildContext context, {
  required ArenaShape shape,
  required CenterObstacle obstacle,
  required double scale,
}) => showDialog<ArenaGeometrySelection>(
  context: context,
  builder: (context) => _ArenaGeometryEditor(
    initialShape: shape,
    initialObstacle: obstacle,
    initialScale: scale,
  ),
);

class _ArenaGeometryEditor extends StatefulWidget {
  const _ArenaGeometryEditor({
    required this.initialShape,
    required this.initialObstacle,
    required this.initialScale,
  });
  final ArenaShape initialShape;
  final CenterObstacle initialObstacle;
  final double initialScale;

  @override
  State<_ArenaGeometryEditor> createState() => _ArenaGeometryEditorState();
}

class _ArenaGeometryEditorState extends State<_ArenaGeometryEditor> {
  late ArenaShape shape = widget.initialShape;
  late CenterObstacle obstacle = widget.initialObstacle;
  late double scale = widget.initialScale;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Arena geometry editor'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 230,
              child: CustomPaint(
                painter: _GeometryPainter(shape, obstacle, scale,
                    Theme.of(context).colorScheme.primary),
              ),
            ),
            DropdownButtonFormField<ArenaShape>(
              initialValue: shape,
              decoration: const InputDecoration(labelText: 'Outer boundary'),
              items: [for (final value in ArenaShape.values)
                DropdownMenuItem(value: value, child: Text(value.label))],
              onChanged: (value) { if (value != null) setState(() => shape = value); },
            ),
            DropdownButtonFormField<CenterObstacle>(
              initialValue: obstacle,
              decoration: const InputDecoration(labelText: 'Center obstacle'),
              items: [for (final value in CenterObstacle.values)
                DropdownMenuItem(value: value, child: Text(value.label))],
              onChanged: (value) { if (value != null) setState(() => obstacle = value); },
            ),
            if (obstacle != CenterObstacle.none) ...[
              Text('Obstacle size: ${(scale * 100).round()}%'),
              Slider(
                value: scale.clamp(0.12, 0.34),
                min: 0.12,
                max: 0.34,
                divisions: 11,
                onChanged: (value) => setState(() => scale = value),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () => Navigator.pop(context, ArenaGeometrySelection(shape, obstacle, scale)),
        child: const Text('Apply'),
      ),
    ],
  );
}

class _GeometryPainter extends CustomPainter {
  const _GeometryPainter(this.shape, this.obstacle, this.scale, this.color);
  final ArenaShape shape;
  final CenterObstacle obstacle;
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.44;
    final pen = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3;
    if (shape == ArenaShape.circle) {
      canvas.drawCircle(center, radius, pen);
    } else {
      canvas.drawRect(Rect.fromCenter(center: center, width: radius * 2, height: radius * 2), pen);
    }
    if (obstacle == CenterObstacle.circle) {
      canvas.drawCircle(center, radius * scale, pen);
    } else if (obstacle == CenterObstacle.square) {
      canvas.drawRect(Rect.fromCenter(center: center, width: radius * scale * 2,
          height: radius * scale * 2), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter old) =>
      old.shape != shape || old.obstacle != obstacle || old.scale != scale || old.color != color;
}
