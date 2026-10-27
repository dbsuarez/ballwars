import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../core/sprites/sprite_atlas.dart';
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

/// The power-up icons, plus the atlas ids of every bundled sprite the game
/// draws. All sheets are cut once from the JSON manifests in `assets/sprites/`
/// by [SpriteRegistry]; painters look frames up with
/// `SpriteRegistry.frame(id, frame)` using the ids below (`powerup.<kind>`,
/// `effect.<EffectSprite>`, `projectile.<ProjectileSprite>`,
/// `anim.<AnimatedEffect>`). The ids are built once, so painting never
/// formats strings. See `docs/SPRITES.md`.
///
/// Icons are plain registry frames too ([of] is `frame(iconId(kind))`): their
/// manifest entries use fit "trim", and [load] registers the kinds without
/// sheet art ([pixelArtOnly]) with `SpriteRegistry.registerDrawn`.
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

  static final List<String> _iconIds = [
    for (final k in PowerUpKind.values) 'powerup.${k.name}',
  ];
  static final List<String> _effectIds = [
    for (final k in EffectSprite.values) 'effect.${k.name}',
  ];
  static final List<String> _projectileIds = [
    for (final k in ProjectileSprite.values) 'projectile.${k.name}',
  ];
  static final List<String> _animIds = [
    for (final k in AnimatedEffect.values) 'anim.${k.name}',
  ];

  static String iconId(PowerUpKind kind) => _iconIds[kind.index];
  static String effectId(EffectSprite kind) => _effectIds[kind.index];
  static String projectileId(ProjectileSprite kind) =>
      _projectileIds[kind.index];
  static String animId(AnimatedEffect kind) => _animIds[kind.index];

  /// The atlas id of the projectile art for a [kind]'s shot, or null when the
  /// shot uses the kind's fitted icon ([of]).
  static String? projectileArtworkId(PowerUpKind kind) => switch (kind) {
    PowerUpKind.pistol ||
    PowerUpKind.sniperRifle => projectileId(ProjectileSprite.pistol),
    PowerUpKind.shotgun => projectileId(ProjectileSprite.shotgun),
    PowerUpKind.gatling => projectileId(ProjectileSprite.gatling),
    PowerUpKind.bow => projectileId(ProjectileSprite.bow),
    PowerUpKind.prismLaser => projectileId(ProjectileSprite.prismLaser),
    PowerUpKind.swapCannon => projectileId(ProjectileSprite.swapCannon),
    PowerUpKind.hook ||
    PowerUpKind.threadHarpoon => projectileId(ProjectileSprite.harpoon),
    PowerUpKind.ricochetDisc => projectileId(ProjectileSprite.ricochetDisc),
    PowerUpKind.rocketLauncher => rocketMissileId,
    PowerUpKind.freeze => effectId(EffectSprite.iceWave),
    _ => null,
  };

  /// Every atlas id this class names, the drawn icons of [pixelArtOnly]
  /// included (they are registered by [load]).
  static List<String> get requiredIds => [
    for (final k in PowerUpKind.values) iconId(k),
    ..._effectIds,
    ..._projectileIds,
    ..._animIds,
    rocketMissileId,
    omegaTendrilsAttackId,
    boomerangProjectileId,
    stickyGooRimId,
  ];

  static Future<void>? _registryLoad;
  static Future<void>? _loading;

  /// [kind]'s icon (64 x 64 px, `powerup.<kind>`), or null before [load] has
  /// finished.
  static ui.Image? of(PowerUpKind kind) => SpriteRegistry.frame(iconId(kind));

  /// Loads the registry and registers the drawn icons (once per registry
  /// load; later calls return the same future).
  static Future<void> load() {
    final registry = SpriteRegistry.load();
    if (!identical(registry, _registryLoad)) {
      // First call, or the registry was reset (tests): register again.
      _registryLoad = registry;
      _loading = _loadAll(registry);
    }
    return _loading!;
  }

  static Future<void> _loadAll(Future<void> registry) async {
    // Every sheet is cut by the registry from its atlas manifest; icons use
    // fit "trim", so their visible art fills 60 px inside a 2 px border.
    await registry;
    // Kinds without sheet art are drawn from their 16 x 16 pixels and go
    // through the same fit, as bundled sprites.
    for (final kind in pixelArtOnly) {
      final id = iconId(kind);
      if (SpriteRegistry.has(id)) continue;
      final recorder = ui.PictureRecorder();
      paintIcon(Canvas(recorder), kind, const Rect.fromLTWH(0, 0, 64, 64));
      final picture = recorder.endRecording();
      final drawn = await picture.toImage(64, 64);
      picture.dispose();
      try {
        await SpriteRegistry.registerDrawn(id, drawn, fit: SpriteFit.trim);
      } on ArgumentError catch (e) {
        // Another load registered it meanwhile.
        debugPrint('PowerUpSprites: $e');
      } finally {
        drawn.dispose();
      }
    }
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

  /// The art [kind]'s shot shows: its projectile sprite, or its icon when it
  /// has none.
  static ui.Image? _projectileArtwork(PowerUpKind kind) {
    final id = PowerUpSprites.projectileArtworkId(kind);
    return id == null ? PowerUpSprites.of(kind) : SpriteRegistry.frame(id);
  }

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
          projectile ? _projectileArtwork(kind) : PowerUpSprites.of(kind),
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
