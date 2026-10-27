import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../domain/power_up.dart';
import 'power_up_pixel_art.dart';
import 'sprite_asset_pipeline.dart';
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
  static ui.Image? _rocketLauncher;
  static ui.Image? _rocketMissile;
  static ui.Image? _omegaTendrilsIcon;
  static ui.Image? _omegaTendrilsAttack;
  static ui.Image? _boomerangIcon;
  static ui.Image? _boomerangProjectile;
  static ui.Image? _stickyGooRim;
  static Future<void>? _loading;

  /// [kind]'s image (16 x 16 px), or null before [load] has finished.
  static ui.Image? of(PowerUpKind kind) => switch (kind) {
    PowerUpKind.rocketLauncher => _rocketLauncher,
    PowerUpKind.omegaTendrils => _omegaTendrilsIcon,
    PowerUpKind.boomerang => _boomerangIcon,
    _ => _images[kind],
  };
  static ui.Image? effect(EffectSprite kind, {bool enabled = true}) =>
      enabled ? _effects[kind] : null;
  static ui.Image? projectile(ProjectileSprite kind) => _projectiles[kind];

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
  }) {
    if (!enabled) return null;
    final frames = _animatedEffects[kind];
    return frames == null ? null : frames[frame % frames.length];
  }

  static ui.Image? get rocketMissile => _rocketMissile;
  static ui.Image? get omegaTendrilsAttack => _omegaTendrilsAttack;
  static ui.Image? get boomerangProjectile => _boomerangProjectile;
  static ui.Image? get stickyGooRim => _stickyGooRim;

  /// Builds every icon image (once; later calls return the same future).
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    final data = await rootBundle.load('assets/sprites/powerups-fixed.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final sheet = (await codec.getNextFrame()).image;
    codec.dispose();
    const fixedCell = 128.0;
    const fixedColumns = 8;
    final kinds = _sheetRects.keys.toList(growable: false);
    for (var index = 0; index < kinds.length; index++) {
      final kind = kinds[index];
      final source = Rect.fromLTWH(
        (index % fixedColumns) * fixedCell,
        (index ~/ fixedColumns) * fixedCell,
        fixedCell,
        fixedCell,
      );
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
      if (kind == PowerUpKind.vampire || kind == PowerUpKind.repulsor) {
        paintIcon(Canvas(recorder), kind, const Rect.fromLTWH(0, 0, 64, 64));
      } else {
        Canvas(recorder).drawImageRect(
          sheet,
          source,
          destination,
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      final picture = recorder.endRecording();
      _images[kind] = await picture.toImage(64, 64);
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
    const effectInset = 12.0;
    const effectDestination = Rect.fromLTWH(6, 6, 84, 84);
    for (final kind in EffectSprite.values) {
      final column = kind.index % 4;
      final row = kind.index ~/ 4;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        effectSheet,
        Rect.fromLTWH(
          column * cellWidth + effectInset,
          row * cellHeight + effectInset,
          cellWidth - effectInset * 2,
          cellHeight - effectInset * 2,
        ),
        effectDestination,
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
    const animatedInset = 10.0;
    for (final kind in AnimatedEffect.values.where(
      (kind) =>
          kind != AnimatedEffect.maximumPower &&
          kind != AnimatedEffect.campfire &&
          kind != AnimatedEffect.tornado,
    )) {
      final frames = <ui.Image>[];
      for (var frame = 0; frame < 4; frame++) {
        final recorder = ui.PictureRecorder();
        final fitted = applyBoxFit(
          BoxFit.contain,
          const Size(
            animatedWidth - animatedInset * 2,
            animatedHeight - animatedInset * 2,
          ),
          const Size.square(86),
        );
        if (kind == AnimatedEffect.explosion) {
          // The sheet's explosion row (flash, fireball, smoke). Its grid cell also catches the flames
          // above, so each frame is cut from the band the explosion art occupies instead.
          final source = Rect.fromLTWH(
            frame * animatedWidth + 8,
            _explosionTop,
            animatedWidth - 16,
            _explosionHeight,
          );
          final fit = applyBoxFit(BoxFit.contain, source.size, const Size.square(90));
          Canvas(recorder).drawImageRect(
            animatedSheet,
            source,
            Alignment.center.inscribe(
              fit.destination,
              const Rect.fromLTWH(3, 3, 90, 90),
            ),
            Paint()..filterQuality = FilterQuality.none,
          );
        } else if (kind == AnimatedEffect.iceImpact) {
          // The sheet's ice-crystal row. Its art reaches into the neighboring rows' cells, so each frame
          // is cut along its own clean rows (_iceRows), placed on one shared origin so the crystals
          // don't jump between frames.
          final (top, bottom) = _iceRows[frame];
          const scale = 90 / (animatedWidth - 16);
          final left = frame * animatedWidth + 8;
          Canvas(recorder).drawImageRect(
            animatedSheet,
            Rect.fromLTRB(left, top, left + animatedWidth - 16, bottom),
            Rect.fromLTWH(
              3,
              48 - (_iceBandHeight / 2 - (top - _iceBandTop)) * scale,
              90,
              (bottom - top) * scale,
            ),
            Paint()..filterQuality = FilterQuality.none,
          );
        } else {
          Canvas(recorder).drawImageRect(
            animatedSheet,
            Rect.fromLTWH(
              frame * animatedWidth + animatedInset,
              kind.index * animatedHeight + animatedInset,
              animatedWidth - animatedInset * 2,
              animatedHeight - animatedInset * 2,
            ),
            Alignment.center.inscribe(
              fitted.destination,
              const Rect.fromLTWH(5, 5, 86, 86),
            ),
            Paint()..filterQuality = FilterQuality.none,
          );
        }
        final picture = recorder.endRecording();
        frames.add(await picture.toImage(96, 96));
        picture.dispose();
      }
      _animatedEffects[kind] = frames;
    }
    animatedSheet.dispose();

    // Molotov fire uses a dedicated tall campfire loop. Keeping it in its own
    // fixed four-cell sheet prevents the horizontal, eel-like silhouette of
    // the general-purpose flame row above.
    final campfireData = await rootBundle.load(
      'assets/sprites/molotov-campfire.png',
    );
    final campfireCodec = await ui.instantiateImageCodec(
      campfireData.buffer.asUint8List(),
    );
    final campfireSheet = (await campfireCodec.getNextFrame()).image;
    campfireCodec.dispose();
    final campfireCellWidth = campfireSheet.width / 4.0;
    final campfireFrames = <ui.Image>[];
    for (var frame = 0; frame < 4; frame++) {
      final recorder = ui.PictureRecorder();
      final sourceSize = Size(
        campfireCellWidth,
        campfireSheet.height.toDouble(),
      );
      final fitted = applyBoxFit(
        BoxFit.contain,
        sourceSize,
        const Size(86, 90),
      );
      Canvas(recorder).drawImageRect(
        campfireSheet,
        Rect.fromLTWH(
          frame * campfireCellWidth,
          0,
          campfireCellWidth,
          campfireSheet.height.toDouble(),
        ),
        Alignment.bottomCenter.inscribe(
          fitted.destination,
          const Rect.fromLTWH(5, 3, 86, 90),
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      campfireFrames.add(await picture.toImage(96, 96));
      picture.dispose();
    }
    _animatedEffects[AnimatedEffect.campfire] = campfireFrames;
    campfireSheet.dispose();

    // Dedicated boundary portal loop: the general effect sheet's portal is a
    // burst, while this one remains open and visibly swirls at the arena rim.
    final arenaPortalData = await rootBundle.load(
      'assets/sprites/arena-portal.png',
    );
    final arenaPortalCodec = await ui.instantiateImageCodec(
      arenaPortalData.buffer.asUint8List(),
    );
    final arenaPortalSheet = (await arenaPortalCodec.getNextFrame()).image;
    arenaPortalCodec.dispose();
    final arenaPortalCellWidth = arenaPortalSheet.width / 4.0;
    final arenaPortalFrames = <ui.Image>[];
    for (var frame = 0; frame < 4; frame++) {
      final recorder = ui.PictureRecorder();
      final source = Rect.fromLTWH(
        frame * arenaPortalCellWidth,
        0,
        arenaPortalCellWidth,
        arenaPortalSheet.height.toDouble(),
      );
      final fitted = applyBoxFit(
        BoxFit.contain,
        source.size,
        const Size.square(92),
      );
      Canvas(recorder).drawImageRect(
        arenaPortalSheet,
        source,
        Alignment.center.inscribe(
          fitted.destination,
          const Rect.fromLTWH(2, 2, 92, 92),
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      arenaPortalFrames.add(await picture.toImage(96, 96));
      picture.dispose();
    }
    _animatedEffects[AnimatedEffect.portal] = arenaPortalFrames;
    arenaPortalSheet.dispose();

    final maximumData = await rootBundle.load(
      'assets/sprites/maximum-power.png',
    );
    final maximumCodec = await ui.instantiateImageCodec(
      maximumData.buffer.asUint8List(),
    );
    final maximumSheet = (await maximumCodec.getNextFrame()).image;
    maximumCodec.dispose();
    final maximumFrames = <ui.Image>[];
    for (var frame = 0; frame < 4; frame++) {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        maximumSheet,
        Rect.fromLTWH(frame * 256.0, 0, 256, 256),
        const Rect.fromLTWH(0, 0, 96, 96),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      maximumFrames.add(await picture.toImage(96, 96));
      picture.dispose();
    }
    _animatedEffects[AnimatedEffect.maximumPower] = maximumFrames;
    maximumSheet.dispose();

    _animatedEffects[AnimatedEffect.tornado] = await SpriteAssetPipeline.load(
      const SpriteSheetSpec(
        name: 'Tornado',
        asset: 'assets/sprites/tornado-animated-v2.png',
        columns: 4,
        rows: 2,
        cellWidth: 440,
        cellHeight: 440,
        safeInset: 12,
      ),
    );

    _animatedEffects[AnimatedEffect.lightning] = await SpriteAssetPipeline.load(
      const SpriteSheetSpec(
        name: 'Lightning strike',
        asset: 'assets/sprites/lightning-strike-8.png',
        columns: 4,
        rows: 2,
        cellWidth: 444,
        cellHeight: 444,
        outputSize: 192,
      ),
    );

    final phaseEightFrames = await SpriteAssetPipeline.load(
      const SpriteSheetSpec(
        name: 'Phase 8 skills',
        asset: 'assets/sprites/phase8-skills.png',
        columns: 4,
        rows: 1,
        cellWidth: 440,
        cellHeight: 440,
        safeInset: 12,
        outputSize: 64,
      ),
    );
    const phaseEightKinds = [
      PowerUpKind.friedChicken,
      PowerUpKind.sniperRifle,
      PowerUpKind.busterSword,
      PowerUpKind.ragingDemon,
    ];
    for (var index = 0; index < phaseEightKinds.length; index++) {
      _images[phaseEightKinds[index]] = phaseEightFrames[index];
    }

    final rocketData = await rootBundle.load(
      'assets/sprites/rocket-launcher.png',
    );
    final rocketCodec = await ui.instantiateImageCodec(
      rocketData.buffer.asUint8List(),
    );
    final rocketSheet = (await rocketCodec.getNextFrame()).image;
    rocketCodec.dispose();
    final half = rocketSheet.width / 2.0;
    Future<ui.Image> crop(Rect source, int size) async {
      final recorder = ui.PictureRecorder();
      final fitted = applyBoxFit(
        BoxFit.contain,
        source.size,
        Size.square(size.toDouble()),
      );
      Canvas(recorder).drawImageRect(
        rocketSheet,
        source,
        Alignment.center.inscribe(
          fitted.destination,
          Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      picture.dispose();
      return image;
    }

    _rocketLauncher = await crop(
      Rect.fromLTWH(0, 0, half, rocketSheet.height.toDouble()),
      64,
    );
    _rocketMissile = await crop(
      Rect.fromLTWH(half, 0, half, rocketSheet.height.toDouble()),
      96,
    );
    rocketSheet.dispose();

    final omegaData = await rootBundle.load(
      'assets/sprites/omega-tendrils.png',
    );
    final omegaCodec = await ui.instantiateImageCodec(
      omegaData.buffer.asUint8List(),
    );
    final omegaSheet = (await omegaCodec.getNextFrame()).image;
    omegaCodec.dispose();
    Future<ui.Image> omegaCell(int column, int size) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        omegaSheet,
        Rect.fromLTWH(column * 256.0, 0, 256, 256),
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      picture.dispose();
      return image;
    }

    _omegaTendrilsIcon = await omegaCell(0, 64);
    _omegaTendrilsAttack = await omegaCell(1, 96);
    omegaSheet.dispose();

    final boomerangData = await rootBundle.load('assets/sprites/boomerang.png');
    final boomerangCodec = await ui.instantiateImageCodec(
      boomerangData.buffer.asUint8List(),
    );
    final boomerangSheet = (await boomerangCodec.getNextFrame()).image;
    boomerangCodec.dispose();
    final boomerangHalf = boomerangSheet.width / 2.0;
    Future<ui.Image> boomerangCell(int column, int size) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        boomerangSheet,
        Rect.fromLTWH(
          column * boomerangHalf,
          0,
          boomerangHalf,
          boomerangSheet.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      picture.dispose();
      return image;
    }

    _boomerangIcon = await boomerangCell(0, 64);
    _boomerangProjectile = await boomerangCell(1, 96);
    boomerangSheet.dispose();

    final gooData = await rootBundle.load('assets/sprites/sticky-goo-rim.png');
    final gooCodec = await ui.instantiateImageCodec(
      gooData.buffer.asUint8List(),
    );
    final gooSheet = (await gooCodec.getNextFrame()).image;
    gooCodec.dispose();
    final gooRecorder = ui.PictureRecorder();
    Canvas(gooRecorder).drawImageRect(
      gooSheet,
      Rect.fromLTWH(
        0,
        gooSheet.height * 0.13,
        gooSheet.width.toDouble(),
        gooSheet.height * 0.56,
      ),
      const Rect.fromLTWH(0, 0, 768, 160),
      Paint()..filterQuality = FilterQuality.none,
    );
    final gooPicture = gooRecorder.endRecording();
    _stickyGooRim = await gooPicture.toImage(768, 160);
    gooPicture.dispose();
    gooSheet.dispose();

    final elementalData = await rootBundle.load(
      'assets/sprites/elemental-powers.png',
    );
    final elementalCodec = await ui.instantiateImageCodec(
      elementalData.buffer.asUint8List(),
    );
    final elementalSheet = (await elementalCodec.getNextFrame()).image;
    elementalCodec.dispose();
    final elementalKinds = [
      PowerUpKind.fireWall,
      PowerUpKind.poisonSwamp,
      PowerUpKind.waterGun,
      PowerUpKind.lightningStrikes,
    ];
    final elementalCell = elementalSheet.width / elementalKinds.length;
    for (var i = 0; i < elementalKinds.length; i++) {
      final recorder = ui.PictureRecorder();
      final source = Rect.fromLTWH(
        i * elementalCell,
        0,
        elementalCell,
        elementalSheet.height.toDouble(),
      );
      final fitted = applyBoxFit(
        BoxFit.contain,
        source.size,
        const Size.square(64),
      );
      Canvas(recorder).drawImageRect(
        elementalSheet,
        source,
        Alignment.center.inscribe(
          fitted.destination,
          const Rect.fromLTWH(0, 0, 64, 64),
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      _images[elementalKinds[i]] = await picture.toImage(64, 64);
      picture.dispose();
    }
    elementalSheet.dispose();

    Future<void> loadExtraSheet(
      String asset,
      List<PowerUpKind> extraKinds,
    ) async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final cell = image.width / extraKinds.length;
      for (var i = 0; i < extraKinds.length; i++) {
        final source = Rect.fromLTWH(
          i * cell,
          0,
          cell,
          image.height.toDouble(),
        );
        final fitted = applyBoxFit(
          BoxFit.contain,
          source.size,
          const Size.square(64),
        );
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          image,
          source,
          Alignment.center.inscribe(
            fitted.destination,
            const Rect.fromLTWH(0, 0, 64, 64),
          ),
          Paint()..filterQuality = FilterQuality.none,
        );
        final picture = recorder.endRecording();
        _images[extraKinds[i]] = await picture.toImage(64, 64);
        picture.dispose();
      }
      image.dispose();
    }

    await loadExtraSheet('assets/sprites/earth-wind.png', [
      PowerUpKind.earthquake,
      PowerUpKind.tornado,
    ]);
    await loadExtraSheet('assets/sprites/energy-wave.png', [
      PowerUpKind.energyWave,
    ]);
    await loadExtraSheet('assets/sprites/flamethrower.png', [
      PowerUpKind.flamethrower,
    ]);
    // Fit visible artwork, rather than the transparent sheet cell, into
    // the icon. Keep a two-pixel safety border and preserve its proportions.
    for (final kind in _images.keys.toList()) {
      final original = _images[kind]!;
      final fitted = await fitVisibleArtwork(original);
      _images[kind] = fitted;
      if (!identical(original, fitted)) original.dispose();
    }
    if (_rocketLauncher != null) {
      _rocketLauncher = await fitVisibleArtwork(_rocketLauncher!);
    }
    if (_omegaTendrilsIcon != null) {
      _omegaTendrilsIcon = await fitVisibleArtwork(_omegaTendrilsIcon!);
    }
    if (_boomerangIcon != null) {
      _boomerangIcon = await fitVisibleArtwork(_boomerangIcon!);
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
    PowerUpKind.speed: Rect.fromLTRB(153, 480, 269, 695),
    PowerUpKind.magnet: Rect.fromLTRB(270, 480, 420, 695),
    PowerUpKind.ghost: Rect.fromLTRB(420, 480, 555, 695),
    PowerUpKind.repulsor: Rect.fromLTRB(555, 480, 706, 695),
    PowerUpKind.timeBubble: Rect.fromLTRB(714, 485, 873, 685),
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

  /// The explosion row of effects-animated.png: the band (pixel rows) its artwork occupies, clear of
  /// the flames above and the portal below.
  static const double _explosionTop = 218;
  static const double _explosionHeight = 196;

  /// The ice-crystal row of effects-animated.png: per frame, the first and last pixel rows that hold
  /// only its art (measured: the portal above and the slashes below touch the grid cell). The band
  /// they share is centered in the frame image.
  static const List<(double, double)> _iceRows = [
    (606, 770),
    (603, 781),
    (603, 784),
    (612, 780),
  ];
  static const double _iceBandTop = 603;
  static const double _iceBandHeight = 181;

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
