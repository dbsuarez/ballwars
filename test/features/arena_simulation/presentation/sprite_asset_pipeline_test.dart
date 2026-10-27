import 'package:ballwars/features/arena_simulation/presentation/sprite_asset_pipeline.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_effect_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lightning = SpriteSheetSpec(
    name: 'Lightning strike',
    asset: 'assets/sprites/lightning-strike-8.png',
    columns: 4,
    rows: 2,
    cellWidth: 444,
    cellHeight: 444,
    outputSize: 192,
  );

  test(
    'normalized lightning uses exact isolated cells and rejects the raw grid',
    () {
      expect(() => lightning.validateDimensions(1776, 888), returnsNormally);
      expect(
        () => lightning.validateDimensions(1774, 887),
        throwsFormatException,
      );
      expect(lightning.frameCount, 8);
    },
  );

  testWidgets('supplied lightning decodes eight transparent isolated frames', (
    tester,
  ) async {
    final frames = await tester.runAsync(
      () => SpriteAssetPipeline.load(lightning),
    );
    expect(frames, hasLength(8));
    expect(
      frames!.every((frame) => frame.width == 192 && frame.height == 192),
      isTrue,
    );
    for (final frame in frames) {
      frame.dispose();
    }
  });

  const spec = SpriteSheetSpec(
    name: 'Tornado',
    asset: 'assets/sprites/tornado-animated-v2.png',
    columns: 4,
    rows: 2,
    cellWidth: 440,
    cellHeight: 440,
    safeInset: 12,
  );

  testWidgets('shared lightning animation exposes all eight once-only frames', (
    tester,
  ) async {
    await tester.runAsync(PowerUpSprites.load);
    final definition =
        ArenaEffectLibrary.definitions[ArenaEffectKind.lightning]!;
    expect(definition.frames, 8);
    expect(definition.stepsPerFrame, 1);
    final frames = [
      for (var step = 0; step < 8; step++)
        ArenaEffectLibrary.frame(ArenaEffectKind.lightning, step),
    ];
    expect(frames.every((frame) => frame != null), isTrue);
    expect(frames.toSet(), hasLength(8));
    expect(
      ArenaEffectLibrary.frame(ArenaEffectKind.lightning, 99),
      same(frames.last),
    );
  });

  test('fixed-grid sprite validation rejects dimensions that can bleed', () {
    expect(() => spec.validateDimensions(1760, 880), returnsNormally);
    expect(() => spec.validateDimensions(1759, 880), throwsFormatException);
    expect(() => spec.validateDimensions(1760, 879), throwsFormatException);
  });

  testWidgets('manual and built-in sprites use the validated loader', (
    tester,
  ) async {
    final frames = await tester.runAsync(() => SpriteAssetPipeline.load(spec));
    expect(frames, isNotNull);
    final loaded = frames!;
    addTearDown(() {
      for (final frame in loaded) {
        frame.dispose();
      }
    });
    expect(loaded, hasLength(8));
    expect(
      loaded.every((frame) => frame.width == 96 && frame.height == 96),
      isTrue,
    );
  });
}
