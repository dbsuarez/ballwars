# Skill Management Roadmap

## Meaning of complete

Skill Management is fully complete when an administrator can create a genuinely new skill without changing Dart code, use it in a live match, test it safely, synchronize it across devices, and reproduce it in replay links and exported videos.

There are **four phases in total**. Phase 1 is complete, so **three phases remain**.

## Phase 1 — Built-in tuning and custom variants

**Status: Complete and deployed**

- Edit built-in skill values.
- Organize built-ins under Weapons, Power-ups, and Traps tabs.
- Search across every category without losing the selected tab.
- Duplicate a built-in skill into a named custom variant.
- Activate one custom variant per base skill.
- Apply damage, duration, projectile count, speed, spread, bounce count, and knockback in live matches.
- Select sprite/vector presentation and a curated sound cue.
- Persist the versioned skill library in Supabase and synchronize it through shared app settings.

### Limitation

A custom variant still uses its base skill's behavior. A Pistol variant remains a pistol even when its values, presentation, and name are changed.

## Phase 2 — True Custom Skill Builder

**Status: In progress**

Implemented in the first vertical slice:

- Create a skill from scratch using a carrier pickup/icon.
- Compose pickup, aimed-fire, or collision triggers.
- Target self, the nearest opponent, or every opponent.
- Deliver an instant, projectile, or area effect.
- Apply damage, healing, freeze, speed, or knockback behavior.
- Customize and preview item/impact rendering, sound, yell, and callout style.
- Preview damaging finishers and restore editor defaults.

Create a skill from reusable behavior blocks instead of cloning one fixed behavior.

### Builder fields

- Category: weapon, power-up, or trap.
- Trigger: pickup, fire, collision, timer, damage taken, or elimination.
- Targeting: self, nearest opponent, chosen direction, every opponent, or arena location.
- Delivery: projectile, beam, area, aura, orbit, boundary hazard, or instant effect.
- Effects: direct damage, damage over time, heal, shield, freeze, speed, pull, push, teleport, stun, or equipment interaction.
- Timing: delay, duration, tick interval, cooldown, projectile count, and repeat count.
- Presentation: icon, projectile/item artwork, impact animation, color, sound, yell, and screen shake.

### Runtime requirements

- Stable IDs for entirely new skills.
- Deterministic execution from the match seed.
- Validation and safe limits for every numeric field.
- Equipment rules, including one-handed/two-handed behavior.
- Multiple effects may be chained in a defined order.
- New skills can be enabled, disabled, duplicated, edited, and deleted.

## Phase 3 — Testing, previews, and safety

**Status: After the builder**

- Add new custom skills to the Power-up Test screen.
- Add admin previews for projectiles, effects, sounds, yells, and finishers.
- Show clear validation errors for impossible combinations.
- Add deterministic simulation tests for composed skills.
- Add performance limits for Mayhem and effect-heavy combinations.
- Verify shared-account synchronization between browser and phone.
- Provide import/export for a skill definition as versioned JSON.

## Phase 4 — Replay links and video export

**Status: Last, by agreement**

- Include custom skill definitions or immutable version references in replay data.
- Ensure old replay links retain their original behavior after a skill is edited.
- Render custom icons, projectiles, effects, names, sounds, yells, and finishers in replay playback.
- Render the same custom visuals in exported videos.
- Add backward-compatible decoding and payload-size limits.
- Verify deterministic live match, replay, and video results.

## Completion checklist

Skill Management can be called fully complete only when all four phases pass:

1. Static analysis.
2. Unit, widget, simulation, persistence, and replay tests.
3. Browser verification.
4. Android phone verification.
5. Cross-device synchronization verification.
6. Production deployment verification.

## Current position

```text
[Phase 1 complete] -> [Phase 2 next] -> [Phase 3] -> [Phase 4 last] -> Fully complete
```

