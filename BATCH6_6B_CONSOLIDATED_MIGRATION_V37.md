# Batch 6B consolidated migration and authoring pass (v37)

Base: cumulative v36 overlay on `ballwars 2026-10-31 1648.zip`.

## Implemented together

- Added `SkillLibrary.migrateAllLegacyArtwork()` for atomic, immutable migration of all persisted custom skills and built-in overrides. Factory definitions are deliberately untouched.
- Added library-level **Convert legacy artwork** action with confirmation, draft-only persistence, and failure feedback. A failed conversion never changes the editor's library.
- Preserved existing explicit Visual Event bindings and playable legacy fallback for dangling effect references.
- Added domain tests for bulk conversion, JSON round trip, idempotence, missing effects, capacity failure, and distinct skills sharing sprite assets.
- Kept previous v36 lifecycle, presentation taxonomy, preview and migration changes in the cumulative patch.

## Verification boundaries

- ZIP CRC and entry manifest validated in this environment.
- Flutter/Dart binaries are not installed here; no `flutter analyze` or `flutter test` was executed. This is not a compiled or runtime-certified release.
- Apply the ZIP as an overlay to the named full project baseline. Run `flutter pub get`, `flutter analyze`, `flutter test test/features/skills`, and device Skill Demo smoke tests before treating 6B as signed off.
