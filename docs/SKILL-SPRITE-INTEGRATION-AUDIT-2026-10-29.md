# Skill, sprite and game-effect integration audit

Reviewed: 2026-10-29. Baseline: `1d89a99` on master.

This is a source and regression-test audit, not a claim of physical-phone,
production Supabase, GPU-memory or listening verification. No gameplay or
rendering changes are implemented by this audit.

## Conclusion

Keep the current sprite import/editor/registry foundation. The main missing
piece is a reusable **Effect Library** connecting sprite assets to explicit
skill events. Today the system exposes a few artwork slots, but a slot does
not consistently represent one visual responsibility throughout the game.

Build this incrementally. Fix visual/collision consistency and existing slot
parity first; do not start by replacing all signature attacks with a generic
effect or by building an unrestricted node editor.

## What already works

- Stable built-in/custom skill IDs, independent variants, category, composed
  trigger/target/delivery, primary and secondary mechanics, and payload-skill
  references with cycle checks.
- Persisted casting, icon/held, projectile, impact and shell sprite references.
- Grip position/rotation/facing, skill scales, tint and global/per-skill effect
  visual preferences.
- Sprite import normalization, isolated frames, frame order, uniform playback
  timing, anchors, artwork scale, opacity, library search, in-place replacement,
  reference checks, offline caching and backup/restore.
- Real-renderer Skill Demo with unsaved drafts, plus Live Arena and finisher
  previews. Demo deliberately bypasses automatic triggers and is not a full
  match-behavior validator.
- An existing shared ArenaEffectLibrary, which is a useful seed for the next
  step, rather than something to discard.

Evidence: [skill model](../lib/features/skills/domain/skill_library.dart),
[sprite metadata](../lib/core/sprites/sprite_atlas.dart),
[registry](../lib/core/sprites/sprite_registry.dart),
[demo](../lib/features/skills/application/skill_demo_controller.dart),
[effect library](../lib/features/arena_simulation/presentation/arena_effect_library.dart).

## Current game usage

| Role | Current support | Important limit |
|---|---|---|
| Pickup/menu icon | Custom sprite, tint, scale/opacity metadata | Shares its skill slot with held artwork |
| Equipped artwork | Custom sprite, scale, grip, facing, per-slot identity | Cannot select a different held sprite from the pickup icon |
| Casting | Separate custom sprite, scale, duration | Owner-centered; active-move lifetime follows only four named native moves |
| Projectile | Custom sprite and size/spin | Trail, exhaust and muzzle flash are not independently bindable sprite effects |
| Hit | Custom transient impact sprite | Common hit lifetime is fixed at 12 simulation steps |
| Explosion | Custom impact sprite can replace explosion artwork | Shares its slot with direct-hit artwork |
| Ground/boundary hazard | Some custom art supported for spikes/goo/swamp | Reuses impact art; curvature/placement are specialized painter logic |
| Target status | Burning, poison, armor, magnetic/time visuals exist | No general per-skill target-status sprite binding |
| Arena hazards | Dedicated renderers and skill tuning | General custom effect selection is not exposed for every hazard component |
| Finisher | Custom projectile/icon and impact lookup; several arena effects reused | Separate choreography and fixed custom-art sizing can diverge from arena settings |
| Replay/video | Reconstructs simulation with skill snapshot | Custom sprite revisions are not frozen with the replay |

## Findings and recommendations

### 1. High priority: visual trap placement can diverge from collision geometry

Spike rendering calls `spikePositions` with spacing derived from scaled artwork;
collision calls the same function with unscaled `fieldRadius`. Because spacing
changes each spike's angle along the arc, increasing effect artwork scale moves
the visible spikes independently of their collision samples. Rendering also
projects bases to the rim separately.

Use one simulation-owned hazard geometry description for collision, warning
outlines and visual placement. Artwork scale should resize the art around those
points; a separate gameplay width/reach setting should change physical coverage.
Add a collision-outline toggle in Skill Demo/Live Arena for checking this.

Evidence: [spike collision](../lib/features/arena_simulation/application/power_up_system.dart),
`_triggerSpikeWalls`; [spike rendering](../lib/features/arena_simulation/presentation/power_up_painter.dart),
`for (final wall in p.spikeWalls)`;
[arc geometry](../lib/features/arena_simulation/domain/power_up.dart), `SpikeWall.spikePositions`.

### 2. High priority: one artwork slot has several meanings

`impactSpriteId` is used for a direct hit, an explosion, spike artwork and goo/
swamp surface artwork. Replacing a hit flash can therefore also replace a
persistent hazard or explosion. `iconSpriteId` similarly serves icons and held
items. These are coupling limits, not evidence that every assignment is broken.

Split **Icon**, **Equipped**, **Direct hit**, **Explosion**, **Ground zone** and
**Target status** bindings. Preserve current appearance through legacy fallbacks
when migrating old definitions. Present each role with a clear thumbnail and
explanation instead of adding another ambiguous “effect” field.

Evidence: [artwork slots](../lib/features/skills/domain/skill_library.dart);
[impact/explosion/hazard consumers](../lib/features/arena_simulation/presentation/power_up_painter.dart),
`paintImpacts`, `p.explosions`, `p.spikeWalls`, `p.stickyGoo`, `p.poisonSwamps`.

### 3. High priority: finishers are not a complete mirror of configured artwork

The custom-art fast path in `_paintMoveEffect` draws a sprite at `radius * .8`
and returns before native signature choreography. `_paintImpact` uses
`radius * 1.8`. Those paths do not read the skill's projectile/effect display
scale. Assigning custom art can therefore change which choreography executes,
not just the appearance of a projectile or hit.

Share a visual resolver and effect bindings across arena, demo and finisher.
Keep cinematic framing and unique choreography, but multiply the configured
visual scale by a documented cinematic scale. Render a custom sprite inside
the appropriate move choreography rather than replacing the whole move with
one traveling image.

Evidence: [finisher renderer](../lib/features/arena_simulation/presentation/harpoon_cinematic.dart),
`_paintMoveEffect`, `_paintImpact`.

### 4. High priority: custom artwork readiness is not part of match readiness

App initialization starts CustomSpriteLoader without awaiting it. The loader
downloads and registers atlases sequentially, and runtime lookups fall back when
an ID is missing. Export waits for built-in sprites and ball images, but does
not establish a barrier for the specific custom sprite dependencies of that
match. First-run/offline/slow-network art can therefore be absent or appear
later; this is a source-derived risk, not a reproduced phone failure.

Resolve all sprite dependencies of enabled skills, payloads and effects before
the countdown/export starts. Reuse the existing Getting Ready UI only while
needed. On failure, visibly offer retry or built-in fallback; do not silently
present a custom-art preview as complete.

Evidence: [app initialization](../lib/app.dart), `initState`;
[loader](../lib/features/sprites/application/custom_sprite_loader.dart);
[export preparation](../lib/features/replay_export/application/replay_video_exporter.dart).

### 5. Medium priority: reusable effect definitions are still code-owned

ArenaEffectLibrary is a static map of IDs and playback metadata. Smoke and water
have no sheet assigned in that map; this does not mean their game moves have no
procedural effects. Speed streaks, burning, time bubbles and magnetic fields
also have dedicated hardcoded artwork lookups. Hand effects expose size/color/
duration but no general custom hand-sprite binding.

Add an editable Effect Library whose entries can reference any uploaded sprite.
Provide global defaults plus per-skill overrides. Retain specialized procedural
renderers for beams, curved hazards and signature moves: a sprite is a visual
resource, not a substitute for geometry or mechanics.

Evidence: [effect definitions](../lib/features/arena_simulation/presentation/arena_effect_library.dart);
[status/hand renderers](../lib/features/arena_simulation/presentation/power_up_painter.dart),
`paintSpeedTrail`, `paintBallEffects`, `paintHeldWeapon`.

### 6. Medium priority: playback/lifetime controls are inconsistent

Sprite metadata has a uniform `stepsPerFrame`; the registry supports looped
playback and progress-based one-shots. Some arena callers override the sheet's
rate, while finishers use library timing. Generic hit artwork is removed after
12 steps (0.2 seconds at 60 Hz), regardless of sheet duration. Casting follows
an active move only for Energy Wave, Shadow Clone, Raging Demon and Omnislash;
composed skills use timed casting.

Put playback policy on the effect binding: once/loop/hold-last, natural duration
or fit-to-event, speed multiplier, start delay, fade in/out and end condition.
Use event-local age so a new effect starts at its first frame. Share a skill
activation handle for “while charging/channeling/status active,” rather than
maintaining a new switch for every native move.

Evidence: [playback API](../lib/core/sprites/sprite_registry.dart);
[casting lifecycle and hit cleanup](../lib/features/arena_simulation/application/power_up_system.dart),
`_startCastingArtwork`, `weaponImpacts.removeWhere`;
[rate overrides](../lib/features/arena_simulation/presentation/power_up_painter.dart).

### 7. Medium priority: sprite-level edits are shared, but skill-local tuning is limited

Opacity, anchor and artwork scale belong to the sprite and affect every skill
using it. Skill tint applies broadly across its art. A translucent blue aura
and an opaque gold aura currently need shared-asset edits or duplicate assets
for some differences. Casting is centered on the owner; there is no common
binding control for hands, target feet, impact direction or front/back layer.

Keep asset defaults, then allow binding-local opacity, tint, X/Y scale, offset,
rotation, facing and layer. Name units clearly: ball radii, seconds, degrees.
Provide attachment presets: Owner body / Left hand / Right hand / Target body /
Target feet / Projectile / Impact point / Arena ground / Boundary arc.

### 8. Medium priority: historical replay artwork is mutable

Replays preserve skill data including sprite IDs, not the referenced sprite
content revision. Replacing an atlas preserves IDs, and repository replacement
removes the old sheet. A historical replay can therefore display newer artwork
or fall back after deletion. Snapshotting mechanics alone does not freeze art.

Introduce immutable asset revision IDs or content hashes and an asset dependency
manifest in saved replays/effect recipes. Retain referenced revisions according
to an explicit storage policy. Offline playback should identify missing assets.

Evidence: [replay snapshot](../lib/features/replay_export/domain/replay_link.dart);
[replacement lifecycle](../lib/features/sprites/data/sprite_atlas_repository.dart), `save`, `delete`.

### 9. Medium priority: no overall decoded-sprite budget

Per-upload caps exist, but the loader loads every atlas and there is no overall
decoded-memory budget or unchanged-revision skip in that loop. At the allowed
maximum, 256 RGBA frames of 256 x 256 represent about 64 MiB of raw frame pixels
for one atlas, excluding temporary sheets and GPU overhead. This is an upper
bound calculation, not a measured memory footprint.

Load/pin dependencies for the active match, cache by revision, evict unused
frames, and expose estimated decoded bytes in the library. Add effect instance
budgets, distance/importance culling and reduced-effects quality options for
Mayhem. Never change damage or timing when reducing visual density.

### 10. Later: composed behavior is not an unrestricted effect graph

The current model has primary and secondary mechanical effects, not arbitrary
ordered effect nodes with independent parameters. Payload chains are supported,
but with aimed-projectile restrictions. Some native skills still have bespoke
behavior. Avoid promising “any combination” from the current editor.

After visual bindings are stable, introduce a bounded list of mechanical effect
steps with explicit per-step parameters and validation. Keep reflection, return,
chain targeting and repeated-hit rules as explicit mechanics; selecting an
explosion sprite must never imply explosion damage.

## Recommended link between skills, effects and sprites

```text
Sprite asset + immutable revision
  -> Effect definition (how art plays, attaches and blends)
    -> Skill visual binding (when/where to use it, local overrides)
      -> Runtime event (activation, shot, collision, status start/end)
        -> Shared visual resolver
          -> Arena / Skill Demo / Finisher / Replay / Video
```

Gameplay effects decide damage, healing, reach, knockback and duration.
Presentation events describe what happened; visual bindings decide how to show
it. Effect playback must not consume gameplay RNG or modify collision geometry.

Suggested binding roles:

| Event/role | Useful examples |
|---|---|
| Charging / casting | Energy Wave aura, hand wind, magic circle |
| Shot / muzzle | Gun flash, water squirt, launcher ignition |
| Projectile / trail | Missile body, smoke exhaust, lightning trail |
| Direct hit / explosion | Slash cut, spark hit, blast animation |
| Ground zone / boundary | Scattered Molotov fire, poison swamp, curved goo |
| Target status | Burning overlay, poison mist, freeze shell, stun stars |
| Shield block / break | Armor crack, shield spark, shattering animation |
| Return / discard / expire | Boomerang catch, dropped weapon, fading portal |

A binding should contain an effect ID/revision, role, attachment, lifetime,
playback, transform, local tint/opacity, layer and optional sound cue. Keep the
effect definition reusable; overrides belong to the skill binding.

## Example: custom gold BOOM-MERANG

1. Keep Boomerang mechanics: flight, hit rules, optional return and knockback.
2. Choose its own icon and a separate held sprite if desired.
3. Bind a hand burst to Shot, a projectile sprite to Flight and a spark trail
   to Projectile travel.
4. Bind a small cut to Direct hit and a separate gold explosion to Explosion.
5. Configure explosion radius/damage in mechanics, independently of its artwork
   scale. Add a target burn overlay only if the skill actually applies burning.
6. Demo shows every binding and its event; finisher uses the same recipe with
   cinematic framing. No Dart edit is needed to swap the supplied artwork.

For Energy Wave, bind charge art to the hands, a channel aura to the owner, beam
art to the directional geometry, and impact art to the targets. The activation
handle ends all channel-only visuals when the skill ends, is interrupted or the
owner dies. This also avoids permanent caster overlays.

## Editor and verification changes worth adding

- Keep the existing four editor tabs. Put reusable visual bindings in
  **Appearance > Effects**, grouped by role, with Label | Control rows.
- Each row: thumbnail, effect name, attachment, size, opacity, Preview and Reset.
  Advanced timing/layer controls expand only when needed.
- Show inheritance explicitly: Global default / Skill override / Unassigned /
  Missing asset / Disabled by Vector preference.
- Extend Skill Demo with collision/target-area outlines, event timeline,
  active-effect count and asset readiness; keep the normal uncluttered view.
- Add an automated matrix across native/custom skills, Sprite/Vector,
  all relevant slots, missing assets, dual wield, arena/finisher/replay/export,
  death/respawn cleanup and older snapshot versions.
- Add first-frame/final-frame and long-animation tests, plus measured phone
  frame time and memory checks with six balls and many simultaneous effects.

## Proposed implementation order

- [x] A. Fix trap geometry consistency, custom-art finisher parity and dependency readiness. See [implementation tracking](EFFECT-SYSTEM-ROADMAP.md) for shipped scope and verification.
- [x] B. Add versioned EffectDefinition + SkillVisualBinding with backward-compatible slot migration. See [binding implementation](EFFECT-BINDINGS.md).
- [x] C. Expose casting, muzzle, trail, hit and explosion roles with per-binding preview controls.
- [ ] D. Add ground/status/block/break roles and migrate native effects incrementally.
- [ ] E. Freeze replay asset revisions; add decoded-memory and effect-instance budgets.
- [ ] F. Extend the mechanical effect graph only after the visual contract is reliable.

Do not mark these recommendations implemented based on this audit.

## Verification performed

292 existing tests passed across `test/core/sprites`, `test/features/sprites`,
`test/features/skills`, the arena power-up painter and the finisher renderer.
These protect current supported behavior; passing them does not prove the gaps
above are covered. No new artwork was generated or edited, and no production
database or asset changes were made.
