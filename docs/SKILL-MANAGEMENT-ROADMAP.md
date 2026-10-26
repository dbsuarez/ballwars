# Skill Management Roadmap

## Meaning of complete

Skill Management is fully complete when an administrator can create a genuinely new skill without changing Dart code, use it live, test it safely, synchronize it across devices, and reproduce it in replay links and videos.

There are **four phases**. Phase 1 is complete, Phase 2 is in progress, and Phases 3-4 remain.

## Phase 1 - Built-in tuning and custom variants

**Status: Complete and deployed**

- [x] Edit built-in skill values.
- [x] Add Weapons, Power-ups, and Traps tabs with cross-category search.
- [x] Duplicate and activate one custom variant per base skill.
- [x] Apply damage, duration, count, speed, spread, bounce, and knockback live.
- [x] Select sprite/vector presentation and curated sounds.
- [x] Persist and synchronize the versioned library through Supabase.

## Phase 2 - True Custom Skill Builder

**Status: In progress**

### Shipped

- [x] Create a skill from scratch using a carrier pickup/icon.
- [x] Compose pickup, aimed-fire, or collision triggers.
- [x] Target self, the nearest opponent, or every opponent.
- [x] Deliver an instant, projectile, or area effect.
- [x] Apply damage, healing, freeze, speed, or knockback.
- [x] Preview item/impact rendering, tier-colored skill names, callouts, and sound in one replayable skill preview.
- [x] Customize yells with Shout, Speech, Thought, or Radio bubbles and Normal, Rare, Epic, or Special styling.
- [x] Preview damaging finishers.
- [x] Restore editor defaults and show a settings guide.
- [x] Use stable IDs and deterministic seeded execution.
- [x] Enable, disable, duplicate, edit, and delete custom skills.

### Remaining

- [ ] Add timer, damage-taken, and elimination triggers.
- [ ] Add chosen-direction and arena-location targeting.
- [ ] Add beam, aura, orbit, and boundary-hazard delivery.
- [x] Add DoT, shield, pull, teleport, stun, and equipment effects.
- [x] Add repeat count and repeat interval.
- [x] Add start delay, DoT tick interval, and cooldown.
- [x] Add configurable colors and screen shake.
- [x] Validate trigger, target, delivery, and carrier compatibility.
- [x] Add explicit one-handed/two-handed equipment choice.
- [x] Chain primary and secondary effects in a defined order.

## Phase 3 - Testing, previews, and safety

**Status: Not started**

- [ ] Add custom skills to Power-up Test.
- [ ] Add full projectile and effect playback previews.
- [x] Add sound, yell, callout, and finisher previews.
- [x] Show clear validation errors for impossible combinations.
- [x] Add deterministic simulation tests for the initial composed runtime.
- [ ] Add Mayhem performance limits for effect-heavy combinations.
- [ ] Verify browser/phone shared-account synchronization.
- [ ] Provide versioned JSON import/export.

## Phase 4 - Replay links and video export

**Status: Last, by agreement**

- [ ] Store immutable custom-skill definitions or version references in replay data.
- [ ] Preserve old replay behavior after a skill is edited.
- [ ] Render custom presentation in replay playback.
- [ ] Render the same presentation in exported videos.
- [ ] Add backward-compatible decoding and payload-size limits.
- [ ] Verify deterministic live, replay, and video results.

## Final completion checks

- [ ] Final static analysis and automated tests pass.
- [ ] Browser verification passes.
- [ ] Android phone verification passes.
- [ ] Cross-device synchronization passes.
- [ ] Production deployment is verified.

## Current position

```text
[x] Phase 1 -> [~] Phase 2 -> [ ] Phase 3 -> [ ] Phase 4 -> Fully complete
```
