# Next Skill Management feature

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
