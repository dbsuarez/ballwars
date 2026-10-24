# Ball Wars Items and Icon Redesign Prompt

Ball Wars currently has 33 items split into weapons, power-ups, and arena traps.

## Weapons

Weapons occupy equipment slots. A ball can normally equip one weapon, or two when Dual Wield is enabled.

| Weapon | Effect |
|---|---|
| Pistol | Aims for 1 second, then fires one bullet dealing 10 damage. |
| Shotgun | Fires 10 scattered pellets. Each pellet deals 10 damage. |
| Gatling | Continuously fires 10 individual rounds, one every 0.1 seconds. Each round deals 15 damage. |
| Knife | Carried until contact, then thrusts into the opponent for 20 damage. |
| Sword | Carried until contact, then performs a wide slash for 40 damage. |
| Shield | Blocks 25% of the next hit, then breaks. Can bash an unarmed opponent for 5 damage. |
| Freeze Gun | Fires an ice wave that freezes the target for 2 seconds. It does no direct damage. |
| Grenade | Thrown toward the target's position. Explodes in an area for 50 damage while sparing its thrower. |
| Molotov | Thrown toward the target. Creates a visible burning area for 3 seconds, dealing 6 damage every 0.5 seconds. Balls caught inside visibly burn. |
| Hook | Hooks and pulls an opponent toward the user, deals 30 damage, then throws the victim away. Yell: "COME OVER HERE!" |
| Ricochet Disc | Fires a disc that can bounce from the arena wall before hitting for 25 damage. |
| Orbiting Flail | A chained flail visibly orbits the equipped ball and strikes opponents within its extended reach for 20 damage. |
| Thread Harpoon | Steals threads in All-Out or drains health in Arsenal. Deals 20 damage. |
| Prism Laser | Fires a beam that splits after bouncing from the arena wall. Deals 18 damage. |
| Swap Cannon | Damages the target for 10, then swaps the shooter's and target's positions and velocities. |
| Bow | Fires a seven-arrow volley in an arcing arrow-rain formation. Each arrow deals 4 damage. |

## Power-ups

Power-ups activate immediately and do not replace equipped weapons.

| Power-up | Effect |
|---|---|
| Apple | Restores 25 health, including overhealing up to 150. In All-Out it restores available lines. |
| Speed | Doubles movement speed for 3 seconds and produces "The Flash" speed streaks. |
| Magnet | Pulls the nearest pickup directly toward the ball. If none exists, it waits for the next pickup. |
| Ghost | Makes the ball intangible and immune to attacks for 3 seconds. |
| Repulsor | Greatly repels other balls on contact for 3 seconds. |
| Time Bubble | Slows nearby opponents and projectiles for 3 seconds. |
| Vampire | Converts part of the damage dealt into health or recovered lines for 3 seconds. |
| Mirror | Reflects the next incoming projectile. |
| Overcharge | Empowers both equipped weapons for 3 seconds. |
| Gremlin | Causes the nearest opponent's next projectile to fire backward. |
| Magnetic Force Field | Surrounds the ball with a purple, Magneto-inspired field twice the ball's size. It repels projectiles and balls; repelled ball collisions deal 5 damage. |
| Golden Armor | Completely blocks the next two damaging hits. |

## Arena Traps

Traps are automatically deployed and do not count as collectible pickups. Deployment begins after 1 minute by default.

| Trap | Effect |
|---|---|
| Mine | Arms on the arena floor and explodes when an opponent enters its range. Deals 50 damage. |
| Phase Mine | A partially hidden proximity mine dealing 40 damage. |
| Portal | Appears at the arena boundary and conforms to its edge. Entering it teleports the ball to a random side of the arena. |
| Spike Wall | Six curved spikes attached directly to the arena boundary. Deals 25 damage and knocks the ball inward. |
| Sticky Goo | A green patch conforming to the boundary. Holds the first ball touching it in place for 2 seconds. |

All damage values are admin configurable.

## Icon Redesign Prompt

> Design a cohesive set of 33 pixel-art game icons for a fast, chaotic arena game called "Ball Wars." Each icon must be drawn on a strict 16x16 pixel grid with a transparent background, crisp hard-edged pixels, no antialiasing, no gradients, no blur, and no text or letters.
>
> The icons must remain immediately recognizable when displayed at 24-40 pixels. Use bold silhouettes, limited high-contrast color palettes, one dominant object per icon, dark outlines, bright highlights, and consistent lighting from the upper-left. Avoid circular badge backgrounds because pickups and traps must not look like balls.
>
> Establish three visually distinct families:
>
> - Weapons: metallic construction, strong directional silhouettes, and warm attack highlights.
> - Power-ups: brighter magical energy, saturated colors, and readable aura motifs.
> - Traps: environmental objects shown without collectible rings, orbs, pedestals, or token backgrounds.
>
> Create icons for:
>
> Weapons: Pistol, Shotgun, Gatling Gun, Knife, Sword, Shield, Freeze Gun, Grenade, Molotov, Hook, Ricochet Disc, Orbiting Flail, Thread Harpoon, Prism Laser, Swap Cannon, and Bow.
>
> Power-ups: Apple, Speed, Magnet, Ghost, Repulsor, Time Bubble, Vampire, Mirror, Overcharge, Gremlin, Magnetic Force Field, and Golden Armor.
>
> Traps: Mine, Phase Mine, Portal, six-spike curved Spike Wall, and green Sticky Goo.
>
> Important visual distinctions:
>
> - Pistol has one short barrel; Shotgun has a wide double barrel; Gatling has several rotating barrels.
> - Grenade is a military fragmentation grenade; Molotov is a glass bottle with a flaming cloth wick.
> - Hook is a heavy curved hook with a chain; Thread Harpoon is a narrow spear attached to bright threads.
> - Ricochet Disc is a sharp cyan throwing disc; Orbiting Flail is a spiked metal ball connected to a chain.
> - Prism Laser uses a crystalline rainbow emitter; Freeze Gun uses icy cyan shapes.
> - Bow must clearly show a curved bow and arrow.
> - Speed uses a yellow lightning bolt with trailing streaks.
> - Ghost uses a pale translucent ghost silhouette.
> - Magnetic Force Field uses purple concentric energy arcs inspired by magnetic power, without copying a copyrighted character or emblem.
> - Golden Armor is a polished gold protective chest plate.
> - Mine is visibly mechanical; Phase Mine is purple, unstable, and partially phased.
> - Portal is an open cyan-and-magenta dimensional doorway.
> - Spike Wall is a connected row of at least six red steel spikes, not a single spike and not a collectible.
> - Sticky Goo is an irregular bright-green boundary puddle with bubbles, not a green orb.
>
> Output the icons as a labeled sprite-sheet concept with each design isolated inside its own 16x16 cell. Keep every silhouette readable, stylistically consistent, and suitable for recreation as exact Flutter pixel-art data.
