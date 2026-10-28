# Known issues

Bugs that are known but left in place on purpose. The first two change what happens in a match, so fixing them would change the outcome of existing replays and the recorded-result tests. Fix them only together with a decision on old replay links (for example, a link version that keeps the old behavior for old links).

## Simulation (changing these changes replays)

### Dual wield: a bump can credit the wrong skill when only the second hand holds a weapon

`PowerUpSystem.onContact` (`lib/features/arena_simulation/application/power_up_system.dart`) lists a ball's weapons with `equippedWeapons` (`[?held, ?heldSecondary]`, empty slots left out) but pairs them by position with `[heldSkillId, heldSecondarySkillId]` (empty slots kept). When only the second slot is filled, the weapon is at index 0 and gets `heldSkillId` (normally null) instead of `heldSecondarySkillId`, so a custom skill based on a contact weapon strikes with the built-in's rules and name. Fix: build the ids list the same way as the weapons list (skip the slot when its weapon is null).

### Endless Battle: Raging Demon attacks survive a respawn

`PowerUpSystem.resetForRespawn` clears the respawning ball's effects, pulls, composed effects and Shadow Clone attacks, but not `ragingDemonAttacks`. A Raging Demon sequence the ball owns or is the target of keeps running after it respawns. Fix: remove the attacks whose owner or target is the ball, like `shadowCloneAttacks`.

## Balance (by design, documented)

### Special-tier spawn odds are per-tier shares

The spawn selector first picks a tier by its weight, then an item inside the tier. A tier with few items (Special has 3) therefore gives each of its items a larger chance than an item of a big tier, even though Special has the smallest weight. See `docs/SPAWN-ODDS.md` for the numbers and the options if per-item odds are wanted.

## Drawing (cosmetic)

### Held weapon: grip flip and sprite flip can disagree for a few frames

While a fired weapon drops after its shot, `PowerUpPainter` places the grip (`heldCenter`, mirrored by the aim direction) with the angle before the recoil, but flips the sprite with the angle after the recoil. Near a vertical aim the two can land on different sides, so for a few frames the sprite is mirrored relative to the hand that holds it. Only the picture is affected, never the match.
