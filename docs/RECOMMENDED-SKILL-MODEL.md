# Recommended Skill Model

This is the source of truth for Ball Wars skills. A skill's identity is separate from the legacy item whose art or defaults it may reuse, so a custom skill is an independent playable entry rather than a replacement for a built-in one.

## Goals

- Built-in edits save exactly, reload locally, and synchronize through the existing account settings path.
- Duplicated and newly created skills coexist with their source skill.
- Weapons, power-ups, traps, and arena traps share one reusable model without exposing irrelevant settings.
- Runtime behavior is data-driven and may combine attack, recovery, defense, control, and movement.
- Old saved settings and replays remain readable after migration.

## Identity and inheritance

Every skill has a stable `id` that never changes when its display name changes.

```text
id                 custom.boom-merang.20261027
name               BOOM-MERANG
templateKind       boomerang
isBuiltIn          false
enabled            true
```

`templateKind` replaces the old concept of a carrier that owns the slot. It supplies optional default artwork, animation, sound, and behavior values. It must never determine the custom skill's identity or hide the original built-in skill.

## Classification

Classification is explicit and is not inferred from `templateKind`.

### Category

- `weapon` — equipped in a weapon slot and fired by its trigger.
- `powerUp` — applies or activates without occupying a weapon slot.
- `trap` — deployable arena hazard available to normal trap selection.
- `arenaTrap` — arena-associated hazard shown in the Traps tab with an `Arena` marker.

### Purpose and capabilities

Purpose is derived from enabled capabilities:

- `attack`: can damage, but cannot heal or defend.
- `recovery`: heals and does not damage.
- `defense`: mitigates damage without dealing damage.
- `hybrid`: combines purposes, such as Vampire dealing damage and healing.

Capabilities are derived from the effect graph: `canDamage`, `canHeal`, `canDefend`, `canControl`, and `canMove`. The editor shows only relevant fields. Adding a Heal effect intentionally exposes healing even for an unusual hybrid weapon.

## Reusable behavior graph

A skill is an ordered graph:

```text
Trigger -> Targeting -> Delivery -> Primary effect -> Secondary effects
```

- Trigger: `pickup`, `aimedFire`, `collision`, `timer`, `damageTaken`, or `elimination`.
- Targeting: `self`, `nearestOpponent`, `allOpponents`, `chosenDirection`, or `arenaLocation`.
- Delivery: `instant`, `projectile`, `area`, `beam`, `aura`, `orbit`, or `boundaryHazard`.
- Effects: damage, damage over time, heal, shield, reflect, freeze, stun, speed, pull, knockback, teleport, explosion, equip, discard, and return behavior.

Each effect owns its parameters. BOOM-MERANG is therefore a projectile with per-flight target hit tracking, no return behavior, knockback, and an explosion—not a Boomerang-only runtime exception.

## Presentation

Presentation is independent of mechanics:

- item/icon visual and scale;
- equipped visual, hand inset, and scale;
- held-art facing policy (automatic, mirror, rotate with aim, or upright), saved from the editor/grip preview;
- projectile visual, scale, spin, trail, and animation;
- casting artwork on the owner, with independent size, finite duration or an active-move lifetime;
- impact visual, scale, animation, and color;
- hand effect and scale;
- sound cue;
- yell text, bubble shape, tier style, and bubble duration;
- finisher profile and screen shake.

Item and impact previews use identical square viewports, fit rules, and center alignment. Missing artwork uses one generic code-drawn placeholder; it must not trigger paid image generation.

Casting and impact are separate slots: casting starts on activation and ends with
its timer or channelled move; impact starts only at the hit. Sprite-library
opacity is non-destructive metadata shared by every use of that sprite, applied
in previews, arena rendering and finishers. Changing presentation settings must
not require recompilation or alter collision/damage behavior.

## Runtime identity

Runtime objects carry `skillId`, not only `PowerUpKind`:

```text
FieldSkill.skillId
EquippedSkill.skillId
Projectile.skillId
ActiveEffect.sourceSkillId
Finisher.skillId
```

The runtime resolves an immutable `SkillDefinition` by ID. `templateKind` is only a fallback for legacy rendering during migration. This lets Boomerang and BOOM-MERANG appear, equip, fire, save, and replay independently.

## Persistence

The serialized library contains a schema version, built-in overrides, independent custom skills, and deleted custom IDs. Its rules are:

1. Compare built-in edits against immutable factory defaults, never already-applied settings.
2. Save validated numeric values and display the validated result immediately.
3. Preserve every enabled custom skill; never disable siblings sharing a template.
4. Synchronize the library through the existing signed-in settings store.
5. Snapshot resolved definitions in replays, or use deterministic version references, so later edits do not rewrite history.

## Backward compatibility

Version-1 data is migrated as follows:

- `base` becomes `templateKind`.
- Category is inferred once from the legacy kind and then saved explicitly.
- Old primary and secondary effects become the first effect entries.
- Existing built-in override IDs remain stable.
- Existing custom variants become independent skills and no longer suppress siblings.
- Runtime objects without `skillId` resolve to `builtin.<legacy kind>`.

Unknown fields are ignored. Missing fields receive documented defaults. Invalid enum values fall back safely and produce a validation warning instead of deleting the skill.

## Editor contract

1. General: name, enabled, category, purpose summary, rarity/tier, and template.
2. Activation: trigger, targeting, delivery, timing, cooldown, and repeats.
3. Effects: an ordered list with only applicable parameters.
4. Visuals: equal item/impact previews plus equipped/projectile/hand controls.
5. Audio and callout: previewable sound, yell, bubble, tier, and duration.
6. Finisher: enabled only for damaging skills, with a live-arena test path.
7. Validation: blocking incompatibilities and non-blocking performance warnings.
8. Restore Default: factory defaults for built-ins; the creation template for customs without deleting their identity.

## Phase 10 acceptance examples

- Edit built-in Boomerang damage from 8 to 7 and knockback from 0 to 20; save, leave, reopen, refresh, and confirm both remain.
- Duplicate Boomerang as BOOM-MERANG; add explosion and knockback, disable return, and verify both skills remain selectable and behave differently.
- Edit Fried Chicken and launch Power-up Test; it appears in the power-up slot, not a weapon slot.
- Configure yell and bubble duration; verify live match, preview, replay, and exported video use them.
- Arena traps appear under Traps with an `Arena` marker and use the generic placeholder when artwork is absent.

