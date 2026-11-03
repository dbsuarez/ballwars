# Batch 30: final piercing policy audit

The inspected projectile resolver treats **returning non-explosive shots** as persistent, with ordered multi-target contacts, obstacles, defenses and hit-history checks. Ordinary non-returning bullets are spent at first accepted target contact. No explicit generic piercing configuration was found in the inspected resolver; this batch does not invent one.

Added two regression cases asserting pistol shots stop at the first target regardless of contestant order. Earlier cumulative tests and fixes are retained.

**Validation:** ZIP integrity checked only. Flutter/Dart analyzer, tests, and web build could not run here. This checkpoint is NOT release-ready. Integrate against approved baseline and run `flutter analyze`, `flutter test --reporter expanded`, `flutter build web --release`, then phone-test.
