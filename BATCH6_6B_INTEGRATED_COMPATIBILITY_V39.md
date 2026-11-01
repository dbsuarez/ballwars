# Batch 6B consolidated compatibility and migration pass (v39)

## Correctness defect addressed

The original Impact sprite is also the legacy fallback for Explosion. Previous
bulk conversion cleared `impactSpriteId` when creating an Impact Visual Event,
which could remove Explosion artwork. This is especially visible on area attacks.

The converter now shares the migrated Impact Visual Event with Explosion when
Explosion does not already have an explicit binding. An explicit Explosion
binding is never overwritten. If Impact is already bound to a separate event,
the legacy sprite is preserved for an unbound or unresolved Explosion role.

## Dry-run and user-facing behavior

The preflight counts an existing Impact binding with no valid Explosion binding
as blocked rather than incorrectly reporting a superseded legacy slot. The
conversion leaves this artwork untouched; this is a compatibility safeguard,
not a destructive migration.

## Regression suite

Added `legacy_vfx_explosion_compatibility_test.dart` covering:
- Legacy Impact/Explosion artwork continuity after bulk migration
- Independent explicit Explosion event priority
- Existing Impact event with unbound Explosion legacy fallback
- Missing Explosion event preserving legacy fallback
- JSON round trip and repeat conversion stability

Updated earlier tests that previously expected two Visual Event bindings after
converting Casting and Impact; there are now three role bindings, backed by
only two distinct effect definitions.

## Verification limits

ZIP archive integrity and source-level invariants verified in this environment.
Flutter and Dart executables are unavailable. Network DNS for Flutter SDK
hosting is unavailable. `flutter analyze`, `flutter test`, and actual game
runtime checks were **not** executed. This is not a certified completed 6B.

## User handoff

Not the user's turn for device testing. First run Flutter static analysis and
full automated tests in an environment with Flutter, fix any reported issues,
then perform targeted Skill Demo, area Explosion, and thrown-weapon playtests.
