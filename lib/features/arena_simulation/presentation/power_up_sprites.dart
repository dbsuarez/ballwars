import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../core/sprites/sprite_registry.dart';
import '../domain/power_up.dart';
import 'power_up_pixel_art.dart';
import '../../skills/presentation/skill_artwork_tint.dart';
import '../../settings/presentation/app_settings_scope.dart';

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

enum AnimatedEffect {
  flame,
  explosion,
  portal,
  iceImpact,
  slash,
  blood,
  maximumPower,
  campfire,
  tornado,
  lightning,
}

/// The power-up icons and effect sprites, cut once from the atlas manifests in
/// `assets/sprites/` by [SpriteRegistry]; this class maps the game's enums to
/// atlas ids (`powerup.<kind>`, `effect.<EffectSprite>`,
/// `projectile.<ProjectileSprite>`, `anim.<AnimatedEffect>`).
///
/// [load] runs once per app; until it finishes (and in tests that skip it) the
/// lookups return null and the painter draws its simple vector glyphs instead.
/// [paintIcon] draws an icon straight from its 16 x 16 pixels, for widgets such
/// as Match Setup's weapons list.
class PowerUpSprites {
  PowerUpSprites._();

  static const rocketMissileId = 'projectile.rocketMissile';
  static const omegaTendrilsAttackId = 'effect.omegaTendrilsAttack';
  static const boomerangProjectileId = 'projectile.boomerang';
  static const stickyGooRimId = 'effect.stickyGooRim';

  /// Kinds with no sheet art: their icons are drawn from [pixelIcons].
  static const pixelArtOnly = {PowerUpKind.vampire, PowerUpKind.repulsor};

  static String iconId(PowerUpKind kind) => 'powerup.${kind.name}';
  static String effectId(EffectSprite kind) => 'effect.${kind.name}';
  static String projectileId(ProjectileSprite kind) =>
      'projectile.${kind.name}';
  static String animationId(AnimatedEffect kind) => 'anim.${kind.name}';

  /// Every atlas id this class looks up.
  static List<String> get requiredIds => [
    for (final k in PowerUpKind.values)
      if (!pixelArtOnly.contains(k)) iconId(k),
    for (final k in EffectSprite.values) effectId(k),
    for (final k in ProjectileSprite.values) projectileId(k),
    for (final k in AnimatedEffect.values) animationId(k),
    rocketMissileId,
    omegaTendrilsAttackId,
    boomerangProjectileId,
    stickyGooRimId,
  ];

  /// Icons after [fitVisibleArtwork]; owned (and never disposed) here.
  static final Map<PowerUpKind, ui.Image> _images = {};
  static Future<void>? _loading;

  /// [kind]'s icon (64 x 64 px), or null before [load] has finished.
  static ui.Image? of(PowerUpKind kind) => _images[kind];
  static ui.Image? effect(EffectSprite kind, {bool enabled = true}) =>
      enabled ? SpriteRegistry.frame(effectId(kind)) : null;
  static ui.Image? projectile(ProjectileSprite kind) =>
      SpriteRegistry.frame(projectileId(kind));

  static ui.Image? projectileArtwork(PowerUpKind kind) => switch (kind) {
    PowerUpKind.pistol ||
    PowerUpKind.sniperRifle => projectile(ProjectileSprite.pistol),
    PowerUpKind.shotgun => projectile(ProjectileSprite.shotgun),
    PowerUpKind.gatling => projectile(ProjectileSprite.gatling),
    PowerUpKind.bow => projectile(ProjectileSprite.bow),
    PowerUpKind.prismLaser => projectile(ProjectileSprite.prismLaser),
    PowerUpKind.swapCannon => projectile(ProjectileSprite.swapCannon),
    PowerUpKind.hook ||
    PowerUpKind.threadHarpoon => projectile(ProjectileSprite.harpoon),
    PowerUpKind.ricochetDisc => projectile(ProjectileSprite.ricochetDisc),
    PowerUpKind.rocketLauncher => rocketMissile,
    PowerUpKind.freeze => effect(EffectSprite.iceWave),
    _ => of(kind),
  };
  static ui.Image? effectFrame(
    AnimatedEffect kind,
    int frame, {
    bool enabled = true,
  }) => enabled ? SpriteRegistry.frame(animationId(kind), frame) : null;

  static ui.Image? get rocketMissile => SpriteRegistry.frame(rocketMissileId);
  static ui.Image? get omegaTendrilsAttack =>
      SpriteRegistry.frame(omegaTendrilsAttackId);
  static ui.Image? get boomerangProjectile =>
      SpriteRegistry.frame(boomerangProjectileId);
  static ui.Image? get stickyGooRim => SpriteRegistry.frame(stickyGooRimId);

  /// Builds every icon image (once; later calls return the same future).
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    // Every sheet is cut by the registry from its atlas manifest.
    await SpriteRegistry.load();
    // Icons fit their visible artwork, rather than the transparent sheet
    // cell, into 64 px with a two-pixel border. The registry cuts each cell
    // to 64 px first ("powerup.<kind>"), then this fit runs on that cut, as
    // before atlases. (Fit "trim" in a manifest measures at sheet resolution
    // and moves some icons by a few px, so the two-step look is kept.) The
    // registry owns its frames, so they are never disposed here.
    for (final kind in pixelArtOnly) {
      final recorder = ui.PictureRecorder();
      paintIcon(Canvas(recorder), kind, const Rect.fromLTWH(0, 0, 64, 64));
      final picture = recorder.endRecording();
      final drawn = await picture.toImage(64, 64);
      picture.dispose();
      final fitted = await fitVisibleArtwork(drawn);
      _images[kind] = fitted;
      if (!identical(drawn, fitted)) drawn.dispose();
    }
    for (final kind in PowerUpKind.values) {
      if (_images.containsKey(kind)) continue;
      final cut = SpriteRegistry.frame(iconId(kind));
      if (cut != null) _images[kind] = await fitVisibleArtwork(cut);
    }
  }

  /// Returns a fitted copy; the caller retains ownership of the input image.
  static Future<ui.Image> fitVisibleArtwork(ui.Image image) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return image;
    var left = image.width, top = image.height, right = -1, bottom = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (bytes.getUint8((y * image.width + x) * 4 + 3) < 16) continue;
        left = math.min(left, x);
        right = math.max(right, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left) return image;
    final source = Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      (right + 1).toDouble(),
      (bottom + 1).toDouble(),
    );
    final fitted = applyBoxFit(
      BoxFit.contain,
      source.size,
      const Size.square(60),
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Alignment.center.inscribe(
        fitted.destination,
        const Rect.fromLTWH(2, 2, 60, 60),
      ),
      Paint()..filterQuality = FilterQuality.none,
    );
    final picture = recorder.endRecording();
    final result = await picture.toImage(64, 64);
    picture.dispose();
    return result;
  }

  /// Draws [kind]'s pixels filling [rect] (one rectangle per pixel; for small widgets, not every frame).
  static void paintIcon(Canvas canvas, PowerUpKind kind, Rect rect) {
    final rows = pixelIcons[kind];
    if (rows == null) {
      _paintFallbackIcon(canvas, kind, rect);
      return;
    }
    var left = pixelSize, top = pixelSize, right = -1, bottom = -1;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (pixelPalette[rows[y][x]] == null) continue;
        left = math.min(left, x);
        right = math.max(right, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left) return;
    final scale =
        math.min(
          rect.width / (right - left + 1),
          rect.height / (bottom - top + 1),
        ) *
        0.94;
    final cell = Size.square(scale);
    final origin =
        rect.center -
        Offset((right - left + 1) * scale / 2, (bottom - top + 1) * scale / 2);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final color = pixelPalette[row[x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + (x - left) * cell.width,
            origin.dy + (y - top) * cell.height,
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
  final bool projectile;
  final int? tint;

  const PowerUpIcon(
    this.kind, {
    super.key,
    this.size = 32,
    this.projectile = false,
    this.tint,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: PowerUpSprites.load(),
    builder: (_, _) => SkillArtworkTint.widget(
      tint ??
          AppSettingsScope.of(context).skillLibrary
              .builtIn(kind, AppSettingsScope.of(context).powerUps)
              .spriteTint,
      CustomPaint(
        size: Size.square(size),
        painter: _IconPainter(
          kind,
          projectile
              ? PowerUpSprites.projectileArtwork(kind)
              : PowerUpSprites.of(kind),
        ),
      ),
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
