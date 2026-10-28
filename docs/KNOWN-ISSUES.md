# Known issues

Bugs that are known but left in place on purpose. The simulation ones change what happens in a match, so fixing them would change the outcome of existing replays and the recorded-result tests. Fix them only together with a decision on old replay links (for example, a link version that keeps the old behavior for old links).

## Simulation (changing these changes replays)

### Dual wield: a bump can credit the wrong skill when only the second hand holds a weapon

`PowerUpSystem.onContact` (`lib/features/arena_simulation/application/power_up_system.dart`) lists a ball's weapons with `equippedWeapons` (`[?held, ?heldSecondary]`, empty slots left out) but pairs them by position with `[heldSkillId, heldSecondarySkillId]` (empty slots kept). When only the second slot is filled, the weapon is at index 0 and gets `heldSkillId` (normally null) instead of `heldSecondarySkillId`, so a custom skill based on a contact weapon strikes with the built-in's rules and name. Fix: build the ids list the same way as the weapons list (skip the slot when its weapon is null).

### Endless Battle: Raging Demon attacks survive a respawn

`PowerUpSystem.resetForRespawn` clears the respawning ball's effects, pulls, composed effects and Shadow Clone attacks, but not `ragingDemonAttacks`. A Raging Demon sequence the ball owns or is the target of keeps running after it respawns. Fix: remove the attacks whose owner or target is the ball, like `shadowCloneAttacks`.

### Shadow Clone: the time freeze outlasts clones that vanish early

Shadow Clone freezes time for its whole planned sequence (`_freezeTime(ShadowCloneAttack.durationFor(clones))`). When the clones vanish early (no opponent left, or the owner goes down), the freeze still runs to its end. Raging Demon behaves the same way. Fix: end the freeze when the attack is removed.

## Video export

### Long ended endless battles: the video can stop before the last knockout

`ReplayVideoExporter` stops at `maxMatchFrames` (10 minutes of video at 30 fps), while `end=` and `nudge=` links allow steps up to `ReplayLink.maxLinkStep` (one hour of game time). The video of an endless battle that was ended after more than 10 minutes therefore stops before its last knockout and winner card. Raising the cap makes exports longer and uses more memory, so it is an owner decision.

## Balance (by design, documented)

### Special-tier spawn odds are per-tier shares

The spawn selector first picks a tier by its weight, then an item inside the tier. A tier with few items (Special has 3) therefore gives each of its items a larger chance than an item of a big tier, even though Special has the smallest weight. See `docs/SPAWN-ODDS.md` for the numbers and the options if per-item odds are wanted.

## Drawing (cosmetic)

### Held weapon: grip flip and sprite flip can disagree for a few frames

While a fired weapon drops after its shot, `PowerUpPainter` places the grip (`heldCenter`, mirrored by the aim direction) with the angle before the recoil, but flips the sprite with the angle after the recoil. Near a vertical aim the two can land on different sides, so for a few frames the sprite is mirrored relative to the hand that holds it. Only the picture is affected, never the match.

## Performance

### Shadow Clone painting allocates per clone per frame

`PowerUpPainter.paintShadowClones` uses one `saveLayer` and several new `Paint` objects for every clone in every frame of the sequence (about 1.5 s). Cached static Paints, with their color or alpha set per call, would remove most of the allocations; the `saveLayer` is what makes each clone translucent as a whole.
