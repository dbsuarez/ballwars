# Shared effect bindings (Phases B-C)

Open **Edit Skill > Appearance > Effects**. Five role cards provide thumbnails,
assignment dropdowns, New, Edit, Preview and Reset. The Effect Library also creates
unassigned reusable definitions, searches names and prevents deletion while used.

## Authoring

Keep the outer four Skill Editor tabs. The effect dialog has three focused tabs:

- Artwork: sprite picker with bundled/uploaded thumbnails, name, shared size and opacity.
- Placement: role-appropriate attachment, local size/opacity, inherited or picked tint,
  facing, forward/side offset in ball radii, and rotation.
- Playback: fit once, loop, play and hold, or natural animation length; event lifetime
  or an explicit visual duration.

Shared artwork/playback edits affect every referencing skill. Placement belongs
only to the current skill. Reset clears its assignment, retaining the reusable
definition and legacy fallback. Changes stay local until Skill Save; Cancel leaves
the saved library unchanged. Preview and Live Arena accept unsaved drafts.

Roles without a corresponding mechanical event explain what to enable. Artwork
does not create projectiles, explosions, damage or healing. A beam cannot gain a
projectile trail merely by assigning artwork. Existing bindings can still be reset.

## Model and compatibility

`SkillLibrary.effects` maps stable IDs to `EffectDefinition` entries: schema,
name, sprite ID, playback, duration, shared scale and opacity. Maximum 256 entries.
`SkillDefinition.visualBindings` maps casting, muzzle, trail, impact (direct hit)
and explosion roles to effect IDs and local placement/style overrides.
`withEffect`, `withEffectDefinitions` and `withoutEffect` validate references;
`resolveVisual` combines definition and binding settings.

Definitions and binding containers write schema 2 and accept schema 1. Libraries
with effects write full version 6 / compact version 7; Phase B versions 4 / 5
remain readable. Libraries without effects retain versions 2 / 3. Invalid numbers,
unknown roles, incompatible attachments and missing references fail clearly.
Update older app builds before importing new snapshots.

Bindings survive save/reload, duplication, import/export and replay encoding.
Restore Defaults clears skill bindings but retains reusable definitions. Asset
readiness, usage searches and replacement/deletion warnings include effect sprites.
Readiness checks active artwork; usage warnings also retain legacy references.

| Unassigned role | Fallback |
|---|---|
| Casting | Legacy casting sprite, scale and duration |
| Direct hit | Legacy impact sprite, effect scale and hit flash |
| Explosion | Legacy impact sprite, effect scale and blast lifetime |
| Muzzle / trail | Existing native appearance |

The old Casting and Impact rows have a visible Legacy pill. Icon/held and
projectile artwork retain their current controls. Broken bindings do not apply
local style overrides to fallback artwork.

## Runtime

Arena, Skill Demo, live finishers and non-interactive video finishers resolve the
same recipes. Finishers retain their signature choreography and cinematic timing.
Muzzle events begin at actual shots and expire independently of held artwork.
Trails use projectile-local age and end when the projectile is removed. Hit art
can follow the target or stay at the impact point. Events retain attack direction.
Cosmetic clocks do not consume simulation RNG or change damage and movement.

Once fits frames to the event, loop follows sprite timing, hold-last plays then
holds the last frame. Natural captures the manifest animation duration when
authored and ends at that duration. Explicit visual duration accepts one simulation
step through 10 seconds; it does not change mechanical timing or camera shake.
Hit visuals have a 512-instance cap; muzzle visuals have a 128-instance cap.

Scale combines the role's existing skill/global scale, definition, binding and
sprite metadata. Opacity combines definition, binding, sprite opacity and fade.
Binding tint overrides skill tint once; unset tint inherits the skill. Placement
uses actual ball radii and event direction. Sprite/Vector preferences still apply.

Ground/status/block/break/discard roles remain Phase D. Immutable historical
sprite revisions and memory budgets remain Phase E.

## Verification

898 automated tests passed, analysis reported no issues, and the web release
build passed. Coverage includes old/new schema round trips, unsaved editor/demo
flows, assignment/reset, library deletion guards, shared definitions, actual shot
and trail lifetime, target attachment, tint/opacity pixels, placement transforms,
finisher rendering and unchanged damage/movement. The effect editor was rendered
and inspected at 390 x 844 and adjusted for readable phone controls and actions.
Real Android/browser account synchronization and production acceptance remain manual.
