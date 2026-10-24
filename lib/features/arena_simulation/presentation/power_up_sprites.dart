import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../domain/power_up.dart';
import 'power_up_pixel_art.dart';

/// The power-up icons ([pixelIcons], 16 x 16 pixel art) turned into small images once, so painting a frame
/// only blits them ([Canvas.drawImageRect] with nearest-neighbor scaling keeps the pixels crisp).
///
/// [load] runs once per app; until it finishes (and in tests that skip it) [of] returns null and the
/// painter draws its simple vector glyphs instead. [paintIcon] draws an icon straight from its pixels,
/// for widgets such as Match Setup's weapons list.
class PowerUpSprites {
  PowerUpSprites._();

  static final Map<PowerUpKind, ui.Image> _images = {};
  static Future<void>? _loading;

  /// [kind]'s image (16 x 16 px), or null before [load] has finished.
  static ui.Image? of(PowerUpKind kind) => _images[kind];

  /// Builds every icon image (once; later calls return the same future).
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    final data = await rootBundle.load('assets/sprites/powerups-master.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final sheet = (await codec.getNextFrame()).image;
    codec.dispose();
    for (final entry in _sheetRects.entries) {
      final recorder = ui.PictureRecorder();
      final fitted = applyBoxFit(
        BoxFit.contain,
        entry.value.size,
        const Size.square(64),
      );
      final destination = Alignment.center.inscribe(
        fitted.destination,
        const Rect.fromLTWH(0, 0, 64, 64),
      );
      Canvas(recorder).drawImageRect(
        sheet,
        entry.value,
        destination,
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      _images[entry.key] = await picture.toImage(64, 64);
      picture.dispose();
    }
    sheet.dispose();
  }

  static const Map<PowerUpKind, Rect> _sheetRects = {
    PowerUpKind.pistol: Rect.fromLTWH(25, 70, 185, 210),
    PowerUpKind.shotgun: Rect.fromLTWH(190, 65, 300, 215),
    PowerUpKind.gatling: Rect.fromLTWH(485, 55, 330, 230),
    PowerUpKind.knife: Rect.fromLTWH(775, 55, 190, 230),
    PowerUpKind.sword: Rect.fromLTWH(940, 55, 200, 230),
    PowerUpKind.shield: Rect.fromLTWH(1115, 45, 230, 245),
    PowerUpKind.freeze: Rect.fromLTWH(1310, 60, 305, 225),
    PowerUpKind.grenade: Rect.fromLTWH(1600, 55, 170, 230),
    PowerUpKind.molotov: Rect.fromLTWH(15, 280, 200, 205),
    PowerUpKind.hook: Rect.fromLTWH(215, 275, 210, 215),
    PowerUpKind.ricochetDisc: Rect.fromLTWH(420, 275, 270, 215),
    PowerUpKind.orbitingFlail: Rect.fromLTWH(675, 275, 210, 220),
    PowerUpKind.threadHarpoon: Rect.fromLTWH(865, 270, 235, 225),
    PowerUpKind.prismLaser: Rect.fromLTWH(1035, 280, 285, 210),
    PowerUpKind.swapCannon: Rect.fromLTWH(1290, 270, 320, 225),
    PowerUpKind.bow: Rect.fromLTWH(1590, 275, 180, 215),
    PowerUpKind.apple: Rect.fromLTWH(15, 485, 155, 195),
    PowerUpKind.speed: Rect.fromLTWH(145, 485, 155, 195),
    PowerUpKind.magnet: Rect.fromLTWH(265, 480, 185, 205),
    PowerUpKind.ghost: Rect.fromLTWH(405, 475, 190, 210),
    PowerUpKind.repulsor: Rect.fromLTWH(545, 470, 220, 215),
    PowerUpKind.timeBubble: Rect.fromLTWH(690, 460, 225, 230),
    PowerUpKind.vampire: Rect.fromLTWH(865, 480, 200, 205),
    PowerUpKind.mirror: Rect.fromLTWH(1015, 475, 180, 215),
    PowerUpKind.overcharge: Rect.fromLTWH(1160, 470, 210, 220),
    PowerUpKind.gremlin: Rect.fromLTWH(1305, 480, 180, 210),
    PowerUpKind.magneticField: Rect.fromLTWH(1440, 460, 220, 235),
    PowerUpKind.goldenArmor: Rect.fromLTWH(1600, 475, 170, 220),
    PowerUpKind.mine: Rect.fromLTWH(425, 685, 200, 200),
    PowerUpKind.phaseMine: Rect.fromLTWH(595, 675, 230, 212),
    PowerUpKind.portal: Rect.fromLTWH(775, 670, 230, 217),
    PowerUpKind.spikeWall: Rect.fromLTWH(975, 675, 230, 212),
    PowerUpKind.stickyGoo: Rect.fromLTWH(1165, 675, 240, 212),
  };

  /// Draws [kind]'s pixels filling [rect] (one rectangle per pixel; for small widgets, not every frame).
  static void paintIcon(Canvas canvas, PowerUpKind kind, Rect rect) {
    final rows = pixelIcons[kind];
    if (rows == null) {
      _paintFallbackIcon(canvas, kind, rect);
      return;
    }
    final cell = Size(rect.width / pixelSize, rect.height / pixelSize);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final color = pixelPalette[row[x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + x * cell.width,
            rect.top + y * cell.height,
            cell.width,
            cell.height,
          ),
          paint,
        );
      }
    }
  }

  /// A compact, always-visible badge for newer kinds that do not yet have a
  /// hand-authored 16 x 16 sprite. The initials keep every item distinct.
  static void _paintFallbackIcon(Canvas canvas, PowerUpKind kind, Rect rect) {
    const colors = [
      Color(0xFF00C9A7),
      Color(0xFFFF6B35),
      Color(0xFF7C5CFF),
      Color(0xFFFF4FD8),
      Color(0xFF58A6FF),
      Color(0xFFFFD000),
    ];
    final color = colors[kind.index % colors.length];
    final center = rect.center;
    final radius = rect.shortestSide * 0.45;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF171722));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.shortestSide * 0.1
        ..color = color,
    );
    final words = kind.label.split(' ');
    final initials = words.length == 1
        ? words.first
              .substring(0, words.first.length >= 2 ? 2 : 1)
              .toUpperCase()
        : words.take(2).map((word) => word[0]).join();
    final text = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: color,
          fontSize: rect.shortestSide * (initials.length == 1 ? 0.58 : 0.43),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }
}

/// A power-up's pixel-art icon as a widget.
class PowerUpIcon extends StatelessWidget {
  final PowerUpKind kind;
  final double size;

  const PowerUpIcon(this.kind, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: PowerUpSprites.load(),
    builder: (_, _) =>
        CustomPaint(size: Size.square(size), painter: _IconPainter(kind)),
  );
}

class _IconPainter extends CustomPainter {
  final PowerUpKind kind;

  _IconPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final image = PowerUpSprites.of(kind);
    if (image == null) {
      PowerUpSprites.paintIcon(canvas, kind, Offset.zero & size);
    } else {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.kind != kind;
}
