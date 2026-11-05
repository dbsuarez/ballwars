# Shared attack emitter

2026-11-05. Local implementation; no deployment or APK release implied.

## Editor

Use Edit Skill > Appearance > Projectiles > Projectile launch point. Enable
the override and adjust Forward/back and Sideways using the two facing previews.
Values are in ball radii. They reuse existing saved skill fields, so no database
migration is needed. Automatic preserves each attack's original placement.

The control is available for native projectile attacks, flamethrower, Energy Wave
and custom beam/projectile delivery. The runtime takes its placement from the
actual equipped skill, including custom identities; it does not store a gun-tip
coordinate in the flamethrower implementation.

## Shared geometry

`AttackEmitter` resolves aim-local forward/sideways coordinates relative to the
current owner position and radius. Mirrored facing keeps an upward offset upward
when facing left. It contains no weapon-specific constants. New sustained attacks
should capture `emitterFor(skill)` when firing and use the resolved point for
both drawing and collision queries.

- Projectiles use this geometry through `projectileOrigin`; their existing arena
  clamp is preserved.
- Flamethrower captures the placement at firing, follows its caster and keeps its
  firing direction steady. Both the flame cone drawing and damage cone use
  `FlameCone.origin`. Custom flame particles start at the emitter rather than
  adding the old ball-edge gap again.
- Energy Wave captures the placement for the charge orb, sweeping beam and damage
  bearing. Extreme offsets still deliver the unavoidable hit by the final sweep
  frame. Its scripted freeze, unavoidable sweep and release remain native
  behavior; configuring its origin does not make it a conventional projectile.
- Custom beam delivery measures its ray from the shared emitter. Impact artwork
  remains on the target. This does not add a new sustained custom-beam behavior
  or turn repeat effects into continuously reevaluated collision volumes.

Sustained emitter positions are not clamped separately to the arena: doing so
would detach a barrel-tip effect from the held item near the wall. Arena drawing
retains its existing boundary clipping. Keep the configured point at the actual
item tip rather than placing it far outside the ball.

## Replay compatibility

New matches use simulation revision 8. Revisions 1–7 retain their previous
continuous-attack origins even when an old saved skill contains offsets. Flying
projectiles preserve their previous mirrored placement and clamping behavior.
The decoder accepts revision 8 and still rejects unknown future revisions.

## Next work

After emitter correctness is verified, proceed with the isolated Flame renderer
feasibility study in the audit roadmap. Keep simulation and replay logic intact.
The named arena editor follows that decision, so it can build on the chosen
rendering approach. No engine migration is authorized by this emitter change.

## Verification

- Full suite: 1,678 passed, one skipped.
- After preserving the exact historical projectile normalization order, 62
  projectile/emitter/editor/replay checks passed again.
- Maintained source, tests and tools: static analysis clean.
- Release web build: passed (73.1 seconds for final build).
- Runtime screenshots inspected in both horizontal facings; upward offsets stay
  upward. Screenshots were produced by Flutter, with no raster asset edits.
- Editor tests cover exposing, adjusting and saving the controls on both native
  flamethrower and Energy Wave. Runtime checks cover displaced cone damage,
  moving-caster placement, custom beam hit rays, old revisions, Energy Wave hits
  and release after extreme offsets.
- Guide Markdown matches the bundled help catalog.

Android device acceptance remains manual. Submitted for deployment and APK
release as v1.14.55 on 2026-11-05; workflow completion is not monitored.
