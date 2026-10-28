# Spawn odds by tier

How often each item group spawns in Arsenal and All-Out matches, at the default settings. Worked out from `PowerUpSpawnSelector` (`lib/features/arena_simulation/application/power_up_spawn_selector.dart`) and the defaults in `PowerUpConfig` (`domain/power_up_config.dart`) and `PowerUpKind.rarity` (`domain/power_up.dart`), as of v1.14.22 plus Shadow Clone (49 kinds).

The numbers assume every item is switched on, nothing is lying on the field yet, and traps have started appearing. The admin can change the tier weights and each item's tier in Settings > POWER-UPS.

## Default odds for one spawn

| Group | Items | Tier weight | Chance of the tier | Chance per item | Share of all spawns |
|---|---|---|---|---|---|
| Normal | 7 | 50 | 29.4% | 4.2% | 25.8% (3.7% each) |
| Rare | 18 | 45 | 26.5% | 1.5% | 23.2% (1.3% each) |
| Epic | 15 | 40 | 23.5% | 1.6% | 20.6% (1.4% each) |
| Special | 3 | 35 | 20.6% | 6.9% | 18.1% (6.0% each) |
| Traps (no tier) | 6 | n/a | n/a | n/a | 12.2% in total (2.0% each) |

"Chance of the tier" and "Chance per item" are within the part of spawns that are not traps (87.8%). "Share of all spawns" includes the trap draw.

## Items in each tier

- **Normal (7):** pistol, knife, apple, speed, magnet, bow, water gun.
- **Rare (18):** shotgun, shield, freeze, grenade, sword, hook, ricochet disc, orbiting flail, prism laser, swap cannon, repulsor, time bubble, vampire, mirror, gremlin, magnetic field, molotov, boomerang.
- **Epic (15):** gatling, thread harpoon, ghost, overcharge, golden armor, rocket launcher, omega tendrils, fire wall, lightning strikes, earthquake, tornado, energy wave, flamethrower, fried chicken, raging demon.
- **Special (3):** sniper rifle, buster sword, Shadow Clone.
- **Traps (6):** mine, phase mine, portal, spike wall, sticky goo, poison swamp.

## How a spawn is chosen

1. **Traps first.** Every eligible item is one entry, traps included, and one entry is drawn to decide "trap or not" (`rng.nextInt(eligible.length)`). With all 49 kinds eligible, the 6 traps take 6 of 49, about 12.2%. If a trap is drawn, it is the pick (and if custom skills are based on that trap, they share it evenly with the built-in).
2. **Then the tier.** For the other 87.8%, a tier is picked by its spawn weight (`rarity.normal` 50, `rarity.rare` 45, `rarity.epic` 40, `rarity.special` 35). The weights are relative: a tier's chance is its weight divided by the total of the tiers that have items (170 here).
3. **Then the item.** The pick inside the chosen tier is uniform, so each item's chance is the tier's chance divided by how many items are in the tier.

## What this means

- Special is the rarest tier (20.6%), but it has only 3 items, so each Special item is the most common single item in the game: about 6.0% of all spawns, against 3.7% for each Normal item and 1.3% for each Rare item.
- Tier weights are shares of the tier, not per-item weights. Moving an item into a tier with few items makes it spawn more often. The same holds for custom skills that have their own tier (a custom skill moved to Special spawns more often).
- If Special should be the rarest item by item, tiers would have to be weighted per item (for example weight times item count, or per-item weights). That changes the odds of every built-in item and makes existing replays play differently, so it is not done.

## What shifts the real odds

- **On the field already:** an item that is already lying on the field cannot spawn again, so the others share its odds. At most `balls + 1` items are on the field at once.
- **Traps start late:** traps only appear after `trapStartSteps`; before that they are left out of the draw.
- **Weapon selection:** anything switched off in Match Setup > Weapons drops out and the rest share its odds. A custom skill that is switched on can spawn even when its base weapon is off.
- **Custom skills:** a custom skill at its base weapon's tier shares that weapon's slot evenly with the built-in. A custom skill with its own, different tier is a separate entry in that tier.
- **Admin tuning:** the tier weights (`rarity.*`), each item's tier (`tier.<kind>`) and the trap start are editable and travel with a match in its replay link (`t=`), so a replay always uses the odds it was played with.

## Reproducing the numbers

Counts come from `PowerUpKind.rarity` (the switch listing normal, special and epic kinds; everything else non-trap is rare) and `PowerUpKind.isTrap`. With 49 kinds and 6 traps there are 43 pickups: 7 + 18 + 15 + 3. The trap share is 6 / 49; each tier's share is its weight / 170 times 43 / 49.
