import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../domain/power_up.dart';
import 'power_up_pixel_art.dart';

enum EffectSprite {
  flame,
  explosion,
  iceWave,
  slash,
  portalBurst,
  shieldImpact,
  speedStreak,
  blood,
  magneticField,
  timeBubble,
  goldenArmorHit,
  stickyGoo,
}

enum ProjectileSprite {
  pistol,
  shotgun,
  gatling,
  bow,
  prismLaser,
  swapCannon,
  harpoon,
  ricochetDisc,
}

enum AnimatedEffect { flame, explosion, portal, iceImpact, slash, blood }

/// The power-up icons ([pixelIcons], 16 x 16 pixel art) turned into small images once, so painting a frame
/// only blits them ([Canvas.drawImageRect] with nearest-neighbor scaling keeps the pixels crisp).
///
/// [load] runs once per app; until it finishes (and in tests that skip it) [of] returns null and the
/// painter draws its simple vector glyphs instead. [paintIcon] draws an icon straight from its pixels,
/// for widgets such as Match Setup's weapons list.
class PowerUpSprites {
  PowerUpSprites._();

  static final Map<PowerUpKind, ui.Image> _images = {};
  static final Map<EffectSprite, ui.Image> _effects = {};
  static final Map<ProjectileSprite, ui.Image> _projectiles = {};
  static final Map<AnimatedEffect, List<ui.Image>> _animatedEffects = {};
  static Future<void>? _loading;

  /// [kind]'s image (16 x 16 px), or null before [load] has finished.
  static ui.Image? of(PowerUpKind kind) => _images[kind];
  static ui.Image? effect(EffectSprite kind) => _effects[kind];
  static ui.Image? projectile(ProjectileSprite kind) => _projectiles[kind];
  static ui.Image? effectFrame(AnimatedEffect kind, int frame) {
    final frames = _animatedEffects[kind];
    return frames == null ? null : frames[frame % frames.length];
  }

  /// Builds every icon image (once; later calls return the same future).
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    final data = await rootBundle.load('assets/sprites/powerups-master.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final sheet = (await codec.getNextFrame()).image;
    codec.dispose();
    final pixels = await sheet.toByteData(format: ui.ImageByteFormat.rawRgba);
    for (final entry in _sheetRects.entries) {
      final source = pixels == null
          ? entry.value
          : _opaqueBounds(pixels, sheet.width, entry.value);
      final recorder = ui.PictureRecorder();
      final fitted = applyBoxFit(
        BoxFit.contain,
        source.size,
        const Size.square(64),
      );
      final destination = Alignment.center.inscribe(
        fitted.destination,
        const Rect.fromLTWH(0, 0, 64, 64),
      );
      Canvas(recorder).drawImageRect(
        sheet,
        source,
        destination,
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      _images[entry.key] = await picture.toImage(64, 64);
      picture.dispose();
    }
    sheet.dispose();

    final effectData = await rootBundle.load(
      'assets/sprites/effects-master.png',
    );
    final effectCodec = await ui.instantiateImageCodec(
      effectData.buffer.asUint8List(),
    );
    final effectSheet = (await effectCodec.getNextFrame()).image;
    effectCodec.dispose();
    const cellWidth = 362.0;
    const cellHeight = 362.0;
    for (final kind in EffectSprite.values) {
      final column = kind.index % 4;
      final row = kind.index ~/ 4;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        effectSheet,
        Rect.fromLTWH(
          column * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        ),
        const Rect.fromLTWH(0, 0, 96, 96),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      _effects[kind] = await picture.toImage(96, 96);
      picture.dispose();
    }
    effectSheet.dispose();

    final projectileData = await rootBundle.load(
      'assets/sprites/projectiles-master.png',
    );
    final projectileCodec = await ui.instantiateImageCodec(
      projectileData.buffer.asUint8List(),
    );
    final projectileSheet = (await projectileCodec.getNextFrame()).image;
    projectileCodec.dispose();
    const projectileCell = 443.5;
    for (final kind in ProjectileSprite.values) {
      final column = kind.index % 4;
      final row = kind.index ~/ 4;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        projectileSheet,
        Rect.fromLTWH(
          column * projectileCell,
          row * projectileCell,
          projectileCell,
          projectileCell,
        ),
        const Rect.fromLTWH(0, 0, 96, 96),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      _projectiles[kind] = await picture.toImage(96, 96);
      picture.dispose();
    }
    projectileSheet.dispose();

    final animatedData = await rootBundle.load(
      'assets/sprites/effects-animated.png',
    );
    final animatedCodec = await ui.instantiateImageCodec(
      animatedData.buffer.asUint8List(),
    );
    final animatedSheet = (await animatedCodec.getNextFrame()).image;
    animatedCodec.dispose();
    const animatedWidth = 362.0;
    const animatedHeight = 181.0;
    for (final kind in AnimatedEffect.values) {
      final frames = <ui.Image>[];
      for (var frame = 0; frame < 4; frame++) {
        final recorder = ui.PictureRecorder();
        final fitted = applyBoxFit(
          BoxFit.contain,
          const Size(animatedWidth, animatedHeight),
          const Size.square(96),
        );
        Canvas(recorder).drawImageRect(
          animatedSheet,
          Rect.fromLTWH(
            frame * animatedWidth,
            kind.index * animatedHeight,
            animatedWidth,
            animatedHeight,
          ),
          Alignment.center.inscribe(
            fitted.destination,
            const Rect.fromLTWH(0, 0, 96, 96),
          ),
          Paint()..filterQuality = FilterQuality.none,
        );
        final picture = recorder.endRecording();
        frames.add(await picture.toImage(96, 96));
        picture.dispose();
      }
      _animatedEffects[kind] = frames;
    }
    animatedSheet.dispose();
  }

  static Rect _opaqueBounds(ByteData pixels, int imageWidth, Rect cell) {
    final left = cell.left.floor();
    final top = cell.top.floor();
    final right = cell.right.ceil();
    final bottom = cell.bottom.ceil();
    var minX = right;
    var minY = bottom;
    var maxX = left;
    var maxY = top;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final alpha = pixels.getUint8((y * imageWidth + x) * 4 + 3);
        if (alpha <= 12) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (minX > maxX || minY > maxY) return cell;
    const padding = 2.0;
    return Rect.fromLTRB(
      math.max(cell.left, minX - padding),
      math.max(cell.top, minY - padding),
      math.min(cell.right, maxX + 1 + padding),
      math.min(cell.bottom, maxY + 1 + padding),
    );
  }

  static const Map<PowerUpKind, Rect> _sheetRects = {
    // These are deliberately non-overlapping cells. Some sprites have wide
    // glows, so content-sized rectangles can accidentally include a neighbor.
    PowerUpKind.pistol: Rect.fromLTRB(0, 0, 214, 286),
    PowerUpKind.shotgun: Rect.fromLTRB(214, 0, 484, 286),
    PowerUpKind.gatling: Rect.fromLTRB(484, 0, 755, 286),
    PowerUpKind.knife: Rect.fromLTRB(755, 0, 908, 286),
    PowerUpKind.sword: Rect.fromLTRB(908, 0, 1098, 286),
    PowerUpKind.shield: Rect.fromLTRB(1098, 0, 1289, 286),
    PowerUpKind.freeze: Rect.fromLTRB(1289, 0, 1593, 286),
    PowerUpKind.grenade: Rect.fromLTRB(1593, 0, 1774, 286),
    PowerUpKind.molotov: Rect.fromLTRB(0, 286, 229, 480),
    PowerUpKind.hook: Rect.fromLTRB(229, 286, 440, 480),
    PowerUpKind.ricochetDisc: Rect.fromLTRB(440, 286, 643, 480),
    PowerUpKind.orbitingFlail: Rect.fromLTRB(643, 286, 845, 480),
    PowerUpKind.threadHarpoon: Rect.fromLTRB(845, 286, 1030, 480),
    PowerUpKind.prismLaser: Rect.fromLTRB(1030, 286, 1278, 480),
    PowerUpKind.swapCannon: Rect.fromLTRB(1278, 286, 1554, 480),
    PowerUpKind.bow: Rect.fromLTRB(1554, 286, 1774, 480),
    PowerUpKind.apple: Rect.fromLTRB(0, 480, 145, 695),
    PowerUpKind.speed: Rect.fromLTRB(145, 480, 270, 695),
    PowerUpKind.magnet: Rect.fromLTRB(270, 480, 420, 695),
    PowerUpKind.ghost: Rect.fromLTRB(420, 480, 555, 695),
    PowerUpKind.repulsor: Rect.fromLTRB(555, 480, 706, 695),
    PowerUpKind.timeBubble: Rect.fromLTRB(706, 480, 877, 695),
    PowerUpKind.vampire: Rect.fromLTRB(877, 480, 1036, 695),
    PowerUpKind.mirror: Rect.fromLTRB(1036, 480, 1157, 695),
    PowerUpKind.overcharge: Rect.fromLTRB(1157, 480, 1316, 695),
    PowerUpKind.gremlin: Rect.fromLTRB(1316, 480, 1451, 695),
    PowerUpKind.magneticField: Rect.fromLTRB(1451, 480, 1595, 695),
    PowerUpKind.goldenArmor: Rect.fromLTRB(1595, 480, 1774, 695),
    PowerUpKind.mine: Rect.fromLTRB(400, 695, 600, 887),
    PowerUpKind.phaseMine: Rect.fromLTRB(600, 695, 786, 887),
    PowerUpKind.portal: Rect.fromLTRB(786, 695, 974, 887),
    PowerUpKind.spikeWall: Rect.fromLTRB(974, 695, 1165, 887),
    PowerUpKind.stickyGoo: Rect.fromLTRB(1165, 695, 1360, 887),
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
    builder: (_, _) => CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(kind, PowerUpSprites.of(kind)),
    ),
  );
}

class _IconPainter extends CustomPainter {
  final PowerUpKind kind;
  final ui.Image? image;

  _IconPainter(this.kind, this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final sprite = image;
    if (sprite == null) {
      PowerUpSprites.paintIcon(canvas, kind, Offset.zero & size);
    } else {
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.kind != kind || old.image != image;
}
