# Shared effect bindings (Phase B)

Implemented foundation: reusable visual definitions, skill references, shared
playback, persistence and dependency tracking. The human-facing Effect Library
editor and role controls are **Phase C**, not part of this batch. Existing
artwork controls remain usable.

## Model

`SkillLibrary.effects` maps stable effect IDs to `EffectDefinition` entries.
Each entry has its own schema version (currently 1), name, sprite ID, playback,
optional duration, scale and opacity. At most 256 definitions are accepted.

`SkillDefinition.visualBindings` maps roles to `SkillVisualBinding` references.
Phase B supports `casting`, `impact` (direct hit) and `explosion` separately.
Bindings hold an effect ID and local scale/opacity multipliers. Multiple skills
can share one definition without sharing their mechanical parameters.

Use `SkillLibrary.withEffect` to add/replace a validated definition.
`withoutEffect` refuses to remove a definition referenced by any skill.
`resolveVisual` resolves the shared definition and the skill's local settings.
`spriteReferences` includes both legacy art and bound effects.

## Compatibility

No binding means the existing slot remains the source of artwork:

| Role | Legacy fallback |
|---|---|
| Casting | `castingSpriteId`, casting scale and casting duration |
| Direct hit | `impactSpriteId`, effect artwork scale and 12-step flash |
| Explosion | `impactSpriteId`, effect artwork scale and existing blast lifetime |

Legacy fallback values are retained when bindings are assigned. Missing
definitions/assets are reported through import validation or runtime readiness;
explicit runtime fallback can still use the old slot. A broken definition
reference does not apply the broken binding's size/opacity to legacy artwork.

The retained Casting and Impact artwork rows have a visible **Legacy** pill and
a tooltip explaining their fallback role. Icon/held and projectile rows are not
marked Legacy because their replacement bindings have not shipped. The older
numbers and rarity editors also use the same pill widget.

Libraries without shared effects retain full version 2 / compact version 3.
Libraries with definitions or bindings write full version 4 / compact version 5.
Readers accept the old forms; unknown schemas, invalid numbers, duplicate IDs,
unknown roles and missing effect references in imported libraries fail clearly.
Older app builds cannot import these new snapshots; update before editing a
library that uses the new schema.

## Runtime behavior

- Casting, direct hits and explosions use `SkillEffectRenderer` when bound.
- Skill Demo uses the same arena renderer and resolves its artwork references
  through the new model.
- Live finishers resolve the same recipes. Video finishers now use the shared
  non-interactive finisher painter rather than the old generic ring animation.
- Cinematic playback fits its existing timeline; it does not lengthen the whole
  cutscene to match an individual effect's duration.
- `once` fits the frame sequence to the event duration; `loop` follows the
  sprite's frame timing; `holdLast` follows natural timing and holds its last frame.
- Optional duration affects visual lifetime only (0.1-10 seconds). Existing
  damage, physical radius, flight, status timing and camera-shake windows stay
  independent. Hit visuals have a 512-instance safety cap.
- Final scale combines the existing skill/global role scale, effect definition,
  binding and sprite metadata. Final opacity combines definition, binding,
  sprite opacity and normal fade. Tint still uses the skill's existing setting;
  binding-local tint/placement controls remain Phase C work.
- Sprite readiness, usage filters, replacement warnings and backup/restore
  warnings include effects. Even an unbound definition counts as an asset
  reference, so deleting its artwork is not presented as harmless.
- Readiness checks the active binding rather than an unused legacy fallback.
  Usage/deletion warnings retain both references, so legacy assignments are
  preserved without preventing a valid replacement effect from starting.

Definitions and bindings survive save/reload, global changes, duplication,
JSON import/export and compact/full replay snapshots. Per-skill Restore Defaults
clears the skill's bindings while retaining reusable library definitions. Sprite
contents are still mutable by stable ID; historical immutable asset revisions
remain Phase E work.

## Verification

New regression coverage includes old/new schema round trips, shared definition
reuse, independent hit/explosion drawing, visual lifetime cleanup, playback
policies, unchanged native damage/movement, dependency traversal, and preserving
bindings when saving through the Skill Editor with Legacy pills visible.

Delivery checks: 888 tests passed, analysis reported no issues, and the web
release build passed. The Legacy pill layout was also rendered and inspected
at 390 x 844. Production account synchronization and real-phone playback are
not claimed as verified by these automated checks.
