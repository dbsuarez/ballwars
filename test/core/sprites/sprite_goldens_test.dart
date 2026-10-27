// Golden contact sheets of every sprite the app draws today. They are the safety net for moving the
// hand-cut sprite code into atlas manifests: later changes must keep matching these images.
//   flutter test test/core/sprites/sprite_goldens_test.dart --update-goldens
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_effect_library.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _cell = 96;
const int _columns = 8;
const Color _background = Color(0xFF3A3F4B);

/// Goldens are generated on Windows but CI runs on Linux, so text-free pixel sheets may differ slightly
/// in rasterization; accept up to 0.5% differing pixels.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    return result.passed || result.diffPercent <= 0.005;
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.images);
  final List<ui.Image?> images;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    final paint = Paint()..filterQuality = FilterQuality.none;
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      if (image == null) continue; // empty cell keeps the layout stable
      final cell = Rect.fromLTWH(
        (i % _columns) * _cell,
        (i ~/ _columns) * _cell,
        _cell,
        _cell,
      ).deflate(4);
      final w = image.width.toDouble(), h = image.height.toDouble();
      final scale = (cell.width / w) < (cell.height / h)
          ? cell.width / w
          : cell.height / h;
      final dst = Rect.fromCenter(
        center: cell.center,
        width: w * scale,
        height: h * scale,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, w, h),
        dst,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) => true;
}

Future<void> _expectSheet(
  WidgetTester tester,
  String name,
  List<ui.Image?> images,
) async {
  final rows = (images.length / _columns).ceil();
  final size = Size(_columns * _cell, rows * _cell);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: SizedBox.fromSize(
          size: size,
          child: CustomPaint(painter: _SheetPainter(images)),
        ),
      ),
    ),
  );
  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Frames of [kind] until the cycle repeats (effectFrame wraps with a modulo).
List<ui.Image?> _frames(AnimatedEffect kind) {
  final first = PowerUpSprites.effectFrame(kind, 0);
  if (first == null) return [null];
  final out = <ui.Image?>[first];
  for (var i = 1; i < 64; i++) {
    final f = PowerUpSprites.effectFrame(kind, i);
    if (identical(f, first)) break;
    out.add(f);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoldenFileComparator previous;
  setUp(() {
    previous = goldenFileComparator;
    goldenFileComparator = _TolerantComparator(
      (previous as LocalFileComparator).basedir.resolve('sprite_goldens_test.dart'),
    );
  });
  tearDown(() => goldenFileComparator = previous);

  testWidgets('sprite contact sheets', (tester) async {
    await tester.runAsync(PowerUpSprites.load);

    await _expectSheet(tester, 'power_up_icons', [
      for (final k in PowerUpKind.values) PowerUpSprites.of(k),
    ]);
    await _expectSheet(tester, 'effect_sprites', [
      for (final k in EffectSprite.values) PowerUpSprites.effect(k),
    ]);
    await _expectSheet(tester, 'projectile_sprites', [
      for (final k in ProjectileSprite.values) PowerUpSprites.projectile(k),
      for (final k in PowerUpKind.values) PowerUpSprites.projectileArtwork(k),
    ]);
    // One row per animated effect, padded to whole rows so rows stay aligned.
    final animated = <ui.Image?>[];
    for (final k in AnimatedEffect.values) {
      final frames = _frames(k);
      animated.addAll(frames);
      while (animated.length % _columns != 0) {
        animated.add(null);
      }
    }
    await _expectSheet(tester, 'animated_effect_frames', animated);
    await _expectSheet(tester, 'special_sprites', [
      PowerUpSprites.rocketMissile,
      PowerUpSprites.omegaTendrilsAttack,
      PowerUpSprites.boomerangProjectile,
      PowerUpSprites.stickyGooRim,
    ]);
    // Extra family: what ArenaEffectLibrary resolves (step 0 and a late step per kind).
    await _expectSheet(tester, 'arena_effect_library', [
      for (final k in ArenaEffectKind.values) ...[
        ArenaEffectLibrary.frame(k, 0),
        ArenaEffectLibrary.frame(k, 7),
      ],
    ]);
  });
}
