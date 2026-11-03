
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/skill_visual_effect.dart';

import 'casting_artwork_test.dart' show setup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('muzzle artwork keeps its firing-time resolved visual', () {
    final match = setup(PowerUpKind.pistol);
    final system = match.powerUps!;
    final owner = match.state.balls.first;
    final skill = match.skillLibrary.builtIn(
      PowerUpKind.pistol, PowerUpConfig.defaults,
    );
    const visual = ResolvedSkillEffect(
      spriteId: 'captured-muzzle.png',
      scale: 1.4,
      opacity: .8,
      tint: 0xFF00AAFF,
      playback: EffectPlayback.once,
      attachment: EffectAttachment.hand,
      facing: EffectFacing.mirror,
      offsetX: .25,
      durationSeconds: .12,
    );
    // Explicitly supplied snapshot is retained even when the effect advances.
    final flash = MuzzleArtwork(owner, skill, const Offset(1, 0), 8,
        resolvedVisual: visual);
    expect(identical(flash.resolvedVisual, visual), isTrue);
    flash.age = 4;
    expect(identical(flash.resolvedVisual, visual), isTrue);
    expect(flash.steps, 8);
    expect(flash.resolvedVisual!.spriteId, 'captured-muzzle.png');
    expect(flash.resolvedVisual!.attachment, EffectAttachment.hand);
    expect(flash.resolvedVisual!.facing, EffectFacing.mirror);
    expect(system.muzzleArtwork, isA<List<MuzzleArtwork>>());
  });
}
