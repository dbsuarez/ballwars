import 'package:ballwars/features/arena_simulation/presentation/sprite_asset_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const spec = SpriteSheetSpec(
    name: 'Tornado',
    asset: 'assets/sprites/tornado-animated-v2.png',
    columns: 4,
    rows: 2,
    cellWidth: 440,
    cellHeight: 440,
    safeInset: 12,
  );

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
