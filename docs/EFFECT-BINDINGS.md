# Shared effect bindings (Phases B-D)

Open **Edit Skill > Appearance > Effects**. Role cards provide thumbnails,
assignment dropdowns, New, Edit, Preview and Reset. Switch between Attack,
Persistent and Events groups; switching keeps the draft. The Effect Library also creates
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
and explosion roles, plus the persistent/event roles below, to effect IDs and local
placement/style overrides.
`withEffect`, `withEffectDefinitions` and `withoutEffect` validate references;
`resolveVisual` combines definition and binding settings.

Definitions write schema 2 and accept schema 1. Binding containers write schema 3
and accept schemas 1-2. Libraries with effects write full version 8 / compact 9;
Phase B versions 4 / 5 and Phase C versions 6 / 7 remain readable. Libraries without effects retain versions 2 / 3. Invalid numbers,
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

Immutable historical sprite revisions and memory budgets remain Phase E.

## Verification

913 automated tests passed, analysis reported no issues, and the web release
build passed. Coverage includes old/new schema round trips, unsaved editor/demo
flows, assignment/reset, library deletion guards, shared definitions, actual shot
and trail lifetime, target attachment, tint/opacity pixels, placement transforms,
finisher rendering and unchanged damage/movement. The effect editor was rendered
and inspected at 390 x 844 and adjusted for readable phone controls and actions.
Real Android/browser account synchronization and production acceptance remain manual.

## Persistent and defensive roles (Phase D)

| Role | Current runtime sources |
|---|---|
| Ground zone | Molotov floor fire; Fire Wall (four samples along its physical wall) |
| Arena boundary | Spike Wall, Sticky Goo, Poison Swamp and Portal |
| Owner status / channel | Speed, Ghost, Repulsor, Time Bubble, Vampire, Mirror, Maximum Power, Magnetic Field, Golden Armor, held Shield/Flail; Energy Wave, Omnislash, Raging Demon, Shadow Clone, Omega Tendrils and Flamethrower channels |
| Target status | Freeze, goo hold, burning, poison, Gremlin, landed Tornado; composed stun and DoT, plus composed Freeze |
| Block | Held Shield, Golden Armor, Mirror reflection and Magnetic Field interception |
| Defense break | Last Shield, Golden Armor or Mirror charge (Magnetic Field expires instead) |
| Expiry | A tracked zone, channel or status ends; not on death/respawn or a charge break |
| Discard | An equipped weapon is removed, replaced or finishes its post-shot hold |

Native procedural attacks keep their choreography. Arena-theme hazards still use
legacy parameter controls, not new editable skill recipes; their physical areas
are visible in the demo inspector. Unsupported role cards explain that their
current behavior emits no corresponding event.

Persistent handles keep local age for one activation. Refreshing a timed buff
restarts its art; a finite visual duration never restarts just because the
underlying buff continues. Removing/interruption of a channel ends its art.
Death and respawn remove attached handles and pending events. World zones keep
their bound artwork for as long as their physical source remains active, even
if its original caster dies. Clearing a status while paused stops its artwork
immediately, without waiting for another simulation step. Bound casting art
also ends with its native channel even when a longer explicit duration is chosen.

Status/ground artwork is independent of physical geometry. Curved art repeats
along unchanged collision sample angles and faces inward; artwork size and local
offsets do not move collisions. Ground art paints beneath balls; statuses and
transient events paint above them. Valid bound status art replaces corresponding
native overlays where supported; missing art and Vector preference use fallback.
Cinematic/export painters reuse applicable ground, boundary and owner/target
recipes at their existing choreography events, using cinematic ball size.
Defensive block/break events are only emitted when an actual defense triggers.

The observer uses no random draws or mechanical mutations. It keeps at most 256
persistent handles, 256 transient events and 60 recent history messages. Skill
Demo's **Inspect effects** shows active source/event counts, the latest eight
history messages and physical outlines. These are demo-only overlays; exported
matches do not contain inspector controls or outlines.


## Phase E implementation update, 2026-10-29

Replay artwork revisions, dependency validation, decoded cache budgets and device visual density are implemented. Placement previews, configurable launch points, reusable AoE controls and remembered demo speed are included. See [implementation and authoring](REPLAY-ARTWORK-REVISIONS.md) and [browser measurements](SIX-BALL-PERFORMANCE.md). Android performance and device/production acceptance remain manual; Phase F is pending. Migration 024 was applied by the user.


## Phase F implementation, 2026-10-29

[Ordered mechanical effect steps](MECHANICAL-EFFECT-STEPS.md) are implemented: up to eight typed steps with independent targeting, delays and relevant parameters. The editor retains its four main tabs and provides a step-by-step dialog under Identity > Behavior. Native built-ins and unconverted primary/secondary skills retain their legacy execution path. New snapshots use schema 12/13; malformed step definitions are rejected explicitly. Demo inspection shows active mechanical effects and budget rejections, and projectile collision outlines follow the separate physical hit radius. Phase E Android profiling remains deferred; device/production acceptance is manual.
