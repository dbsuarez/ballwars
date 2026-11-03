import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/presentation/skill_effect_renderer.dart';

void main() {
  group('Phase 4 shared Visual Events and legacy playback timing', () {
    test('creation-time zero duration does not produce NaN or infinity', () {
      expect(SkillEffectRenderer.progress(0, 0), 0);
      expect(SkillEffectRenderer.remaining(0, 0), 1);
      expect(SkillEffectRenderer.progress(1, 0), 1);
      expect(SkillEffectRenderer.remaining(1, 0), 0);
    });

    test('negative ages are treated as the first frame', () {
      expect(SkillEffectRenderer.progress(-30, 60), 0);
      expect(SkillEffectRenderer.remaining(-30, 60), 1);
    });

    test('expired effects never produce negative opacity or progress', () {
      expect(SkillEffectRenderer.progress(900, 60), 1);
      expect(SkillEffectRenderer.remaining(900, 60), 0);
    });

    test('normal lifetime progresses continuously and retains bounds', () {
      expect(SkillEffectRenderer.progress(15, 60), .25);
      expect(SkillEffectRenderer.remaining(15, 60), .75);
      expect(SkillEffectRenderer.progress(30, 60), .5);
      expect(SkillEffectRenderer.remaining(30, 60), .5);
    });
    test('natural sprite playback remains bounded independently of lifetime', () {
      expect(SkillEffectRenderer.naturalProgress(-1, 4, 3), 0);
      expect(SkillEffectRenderer.naturalProgress(3, 4, 3), .25);
      expect(SkillEffectRenderer.naturalProgress(6, 4, 3), .5);
      expect(SkillEffectRenderer.naturalProgress(100, 4, 3), 1);
      expect(SkillEffectRenderer.naturalProgress(1, 0, 3), 0);
      expect(SkillEffectRenderer.naturalProgress(1, 4, 0), 0);
    });

    test('render alpha is bounded for malformed and expired visuals', () {
      expect(SkillEffectRenderer.boundedOpacity(1, 1), 1);
      expect(SkillEffectRenderer.boundedOpacity(.5, .5), .25);
      expect(SkillEffectRenderer.boundedOpacity(3, 2), 1);
      expect(SkillEffectRenderer.boundedOpacity(-1, 1), 0);
      expect(SkillEffectRenderer.boundedOpacity(1, -1), 0);
      expect(SkillEffectRenderer.boundedOpacity(double.nan, 1), 0);
      expect(SkillEffectRenderer.boundedOpacity(1, double.infinity), 0);
    });
  });
}
