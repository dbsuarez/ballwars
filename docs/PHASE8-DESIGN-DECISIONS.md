# Phase 8 design decisions

## Arena branding rotation

Arena branding remains static by default. Automatic minute-by-minute rotation is deferred because moving branding competes with combat effects, makes replay frames less predictable, and can reduce text readability on busy arena themes. Players choose the arena for each match in match setup, and that device remembers the choice. The admin arena control remains available as the default and as a future arena-authoring/configuration surface. If rotation is revisited, it should be an explicit option with a configurable interval and should use deterministic match time so live play and replays agree.

The Chaotic preset deliberately combines the Space, Desert, Wilderness, and Neon Grid floor treatments in four quadrants. Every deployment cycle creates Gravity Well, Quicksand, Vine Snare, and Laser Gate together; all remain automatic arena fixtures and share the admin arena-trap controls.

## Non-circular contestants

The current simulation is built around circular contestants: collision normals, rim containment, spawn spacing, contact distance, targeting reach, and effect ranges all use a single radius. True rectangles, capsules, or polygons would make collision distance orientation-dependent and introduce corner tunnelling, unequal reach, rotational inertia, and visual-versus-physics fairness problems.

The recommended first step is cosmetic shape variety rendered inside the existing circular hitbox. This preserves identical movement, reach, collision response, and spawn fairness for every contestant. True shape physics should only be introduced as a separately tested mode using convex collision detection (such as SAT), continuous collision checks for fast corners, equal-area/equal-mass normalization, a standardized maximum reach, and telemetry comparing hit and survival rates by shape.

## Phase 8 generated skill sprites

`assets/sprites/phase8-skills.png` is a transparent 4-by-1 sheet with fixed 440 px square cells. Each cell is normalized through the validated sprite pipeline with safe padding before it is displayed at gameplay size. Cell order is Fried Chicken, Special Sniper Rifle, Buster Sword, and Raging Demon.

Generation specification: polished crisp 16-bit arcade pixel art matching the existing colorful Ball Wars sprites; strong silhouettes readable at 32-64 px; exactly four distinct icons in one horizontal row of equal square cells; each icon centered at a consistent visual scale with at least 12.5% transparent safe padding; transparent RGBA background; no text, grid, border, shadow, clipping, overlap, or neighbouring-cell bleed. Colors are warm golden brown for Fried Chicken, metallic gold and black for Sniper Rifle, dark steel and gold for Buster Sword, and deep red, black, and crimson for Raging Demon.
