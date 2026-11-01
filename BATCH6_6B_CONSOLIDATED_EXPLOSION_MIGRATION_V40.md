# Batch 6B: Explosion/Impact split migration and preflight integration (v40)

## Implementation

- Migrating a skill with an explicitly configured Impact Visual Event no longer leaves its legacy Explosion fallback in an obsolete artwork slot forever. The old Explosion sprite is converted to an independent Explosion Visual Event while retaining the explicit Impact event unchanged.
- A single reusable `_legacyEffectFor` implementation handles effect ID collision resolution, existing effect reuse, and the 256-effect capacity guard for both Impact/Casting and Explosion conversion paths.
- The library-wide migration preflight now predicts new or reused Explosion effects, accounts for capacity, and no longer falsely calls convertible artwork blocked.
- Missing explicit Explosion events continue to preserve their legacy fallback instead of destroying artwork.

## Regression tests

Updated/added cases for explicit Impact and unbound Explosion, existing Explosion event reuse, deterministic ID collisions, capacity rollback, idempotence, and preservation of missing Explosion bindings.

## Verification

Source-level structural assertions and cumulative ZIP CRC verification performed. Flutter/Dart SDK is not installed here, so compilation and Flutter tests have not run. Do not treat the patch as a production-certified build.

## Device handoff

Not yet. A developer with a Flutter SDK must run `flutter pub get`, `flutter analyze`, and `flutter test` on the fully overlaid project before the device smoke test.
