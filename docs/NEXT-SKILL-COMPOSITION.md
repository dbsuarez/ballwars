# Next Skill Management feature

## Resume checkpoint (2026-10-27)

- Released source: master `493b1ea`, tag `v1.14.17`, both pushed. Pages deployment and signed APK workflows triggered; remote completion was deliberately not monitored.
- Verification: full 462-test suite passed; two subsequently added effect-preference/replay tests passed in the focused seven-test suite. Static analysis clean and release web build passed.
- Current changes: integer steppers, general Effect visuals in Edit Skill > Appearance, admin Sprite defaults, per-mode player Default/Sprite/Vector preference, replay/export propagation. Explicit skill override wins over player preference, then admin defaults. Existing vector-only effects retain procedural rendering; do not assume dedicated sprites exist for every effect.
- Earlier work includes editor tabs, fixed Preview/Live Arena/Finisher toolbar, direct repository Save with visible errors/retry, separate Save Library for bulk edits, per-skill artwork tint including gold, and replay naming using datetime and contestant names.
- Production migration `020_replay_documents.sql` was confirmed applied by the user. Browser, Android phone, cross-device synchronization, and production verification remain unchecked.
- The requested MemPalace write failed because another writer holds its lock (PID 32484). No process was stopped and no lock bypass attempted. This committed file is the fallback handoff for Claude.

## Working rules

- Preserve user-owned deletion `docs/fame_1597.jpg` and untracked `docs/BALLWARS-HANDOFF.md`; inspect the checkout before touching other edits, particularly `settings_screen.dart`.
- Deploy means push master. APK release requires explicit release instruction and a version tag. Do not monitor GitHub Actions or install on a device.
- Group long editors into tabs, use fixed labels beside controls, right-aligned numeric values, visual pickers, and aligned artwork previews. Report save failures visibly.
- No AI raster generation/editing. Use PhotoCraft CLI for raster processing, VectorCraft for local vector work, and SoundCraft for audio. Read `AGENTS.md`, `docs/PHOTOCRAFT-CLI-HANDOFF.md`, and the relevant notes in `D:\Development\artcraft-usage` first. Provide prompts for new illustrated art so the user can generate elsewhere.
- User chose to release first and defer the composition expansion because session usage was low. No combination code has been started.

## Requested next feature

Requested example: a separate skill equipped with Knife artwork that fires three Boom-merang projectiles.

Not implemented in the current release. Resume after deployment/release; avoid spending the remaining session allowance on this expansion.

## Required shared-model changes

- Separate equipped artwork from the carrier used for equipment rules.
- Add a stable fired-skill reference, selectable from compatible built-in and custom projectile skills, including saved Boom-merang.
- Keep projectile count on the firing skill (three for the example).
- Resolve the fired definition at launch, retaining its return behavior, explosion, knockback, damage, visual scale, tint, and sound.
- Preserve original Knife, Boomerang, and Boom-merang as independent definitions.
- Add icon previews to the selectors and explain which values belong to the firing skill versus the payload.
- Validate missing, incompatible, self-referencing, or cyclic payload references visibly.
- Verify save/reload, live arena, simultaneous independent skills, replay snapshots, and finishers before marking complete.

## Relevant implementation points

- `lib/features/skills/domain/skill_library.dart`: definition serialization, validation, replay snapshots.
- `lib/features/skills/presentation/skill_management_screen.dart`: editor tabs and direct repository save callback.
- `lib/features/arena_simulation/application/power_up_system.dart`: `_launchComposed` currently uses the same definition for the equipped item and each projectile; `_composedProjectiles` retains individual projectile definitions.
- `lib/features/arena_simulation/presentation/power_up_painter.dart`: held artwork, projectile artwork and per-skill tint scopes.

Current work before this feature: integer steppers; general Effect visuals selector; admin sprite defaults; per-mode player preference; replay/export preference propagation.
