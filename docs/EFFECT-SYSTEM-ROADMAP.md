# Skill and sprite effect-system improvements

Source: [2026-10-29 audit](SKILL-SPRITE-INTEGRATION-AUDIT-2026-10-29.md).
This tracks implementation separately from the original source findings.

## A. Existing integration correctness

- [x] Keep rendered spike angles tied to collision sample spacing when artwork scale changes.
- [x] Remove the custom-art finisher fast path that replaced native choreography with one traveling image.
- [x] Resolve custom art inside item, bullet, shotgun volley, arrow, Boomerang and missile rendering paths.
- [x] Honor projectile and held-item scale independently; use effective global/per-skill effect scale for custom impacts/explosions.
- [x] Pass the skill library to match, editor, Power-up Test and gallery finishers; use a custom skill's visual template when no explicit visual move is supplied.
- [x] Add a match dependency barrier for enabled skill artwork, payload dependencies and automatic traps.
- [x] Keep Threads independent of trap/pickup asset requirements.
- [x] Present Retry / Use fallback if required match artwork is missing, before countdown.
- [x] Preflight custom sprite dependencies before exporting video; report missing assets before rendering starts.
- [x] Check unsaved draft artwork before both Skill Demo activation and incoming-hit tests.
- [x] Coalesce concurrent loads by loader and reuse unchanged decoded atlas revisions.
- [x] Keep bounded preparation waits; keep existing ball-image/built-in background loading behavior.

Verification: full suite 875 tests passed, plus the added rendered-spike geometry
regression test passed separately. New tests exercise native seven-pellet
choreography with custom artwork, independent held/projectile scales, actual
rendered spike angles at 1x/3x, explicit fallback interaction, dependency traversal
and unchanged-atlas reuse. Web release build passed. Phone/network and GPU-memory
verification remain manual.

These changes fix existing integration paths. They do not introduce arbitrary
sprite bindings for procedural beams/status effects, a new Effect Library, or
immutable historical replay artwork. No mechanics or replay simulation version
was changed.

## B. Versioned Effect Library and bindings

- [x] Define reusable EffectDefinition entries with stable IDs and a schema version.
- [x] Define SkillVisualBinding roles separately from mechanical effects (initial casting, direct-hit and explosion roles).
- [x] Add shared visual resolution for arena, demo, finisher and export.
- [x] Migrate existing slots through explicit fallbacks, preserving old skill/replay appearance.
- [x] Preserve bindings through save/reload, duplicate, reset, import/export and compact replay encoding.
- [x] Include effect assets in readiness, replacement warnings and sprite usage searches.
- [x] Mark retained fallback controls and older editors with a visible Legacy pill.

Details: [EFFECT-BINDINGS.md](EFFECT-BINDINGS.md). This is the model/runtime
foundation; Phase C below adds authoring controls.

## C. Initial editable visual roles

- [x] Separate casting, muzzle, projectile trail, direct hit and explosion bindings.
- [x] Expose sprite, attachment, size, opacity, tint, facing, offset, playback and lifetime controls.
- [x] Keep the four Skill Editor tabs; group these controls under Appearance > Effects.
- [x] Provide thumbnails, role explanations, reset and preview controls.
- [x] Add effect-local age and once/loop/hold-last/natural-duration policies.
- [x] Preview each role through actual runtime events in Skill Demo.

Verification: 898 tests passed, analysis reported no issues, and the web release build passed. The editor was rendered and inspected at 390 x 844; phone control widths and dialog actions were adjusted. Device and production acceptance remain manual.

## D. Persistent and defensive effects

- [x] Add ground-zone and curved-boundary bindings without changing hit areas.
- [x] Add owner/target status, block, break, expiry and discard event bindings.
- [x] Tie channel/status artwork to activation handles, ending on interruption, death or respawn.
- [x] Migrate native effects incrementally while preserving signature choreography.
- [x] Add collision outlines and an effect-event inspector to the demo.

Scope: ground bindings for Molotov and Fire Wall; curved-boundary bindings for
spikes, goo, poison swamp and portals. Owner buffs/channels, target Freeze/stun/DoT,
shield/armor/Mirror/magnetic blocks, charge breaks, source expiry and weapon discard
use cosmetic activation handles. Native artwork remains the fallback; procedural
signature attacks and the legacy arena-theme trap controls are retained.

Skill Demo adds opt-in physical outlines and a bounded event inspector. See
[EFFECT-BINDINGS.md](EFFECT-BINDINGS.md) for exact event support and limits.

Verification: 913 tests passed, analysis reported no issues, and the web release
build passed. New regressions exercise real armor and Mirror defenses, Freeze
and composed stun, buff refresh/expiry, paused clearing, channel interruption,
respawn/death cleanup, persistent world-zone lifetime, curved sample invariance,
post-shot discard, schema compatibility, draft saves and unchanged RNG/damage.
The Persistent role group was rendered and inspected at 390 x 844. Android and
production acceptance remain manual; deployment workflows are not monitored.

## E. Asset reproducibility and performance

- [ ] Preserve immutable sprite revisions for historical replays and exports.
- [ ] Add replay dependency manifests and an explicit missing-revision policy.
- [ ] Add total decoded-memory estimates and a cache/eviction budget.
- [ ] Add effect-instance budgets and visual-quality density settings without changing mechanics.
- [ ] Measure six-ball performance and memory on actual browser/Android devices.

## F. Mechanical effect composition

- [ ] Replace the two-effect ceiling with a bounded ordered list of effect steps.
- [ ] Give each step its own parameters and targeting rules.
- [ ] Validate loops, scheduled-event limits, repeated hits and interruption cleanup.
- [ ] Keep damage, reach, knockback and status timing independent of selected artwork.
- [ ] Maintain old snapshots and add end-to-end composition regression coverage.

A-D are implemented. E-F remain explicit follow-up work.
