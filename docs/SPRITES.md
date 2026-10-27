# Sprites

For a developer adding or fixing a sprite in Ball Wars. Every bundled sprite
(power-up icons, effects, projectiles, animations) is cut at start-up from a
sheet PNG in `assets/sprites/`, following a JSON manifest next to it. Nothing
in the Dart code holds pixel rectangles any more.

## How it fits together

- `assets/sprites/<sheet>.png`: the artwork.
- `assets/sprites/<sheet>.atlas.json`: the manifest. It names the sheet and,
  for each sprite id, its frame rectangles and how to cut them.
- `assets/sprites/atlas-index.json`: the list of manifests to load.
- `lib/core/sprites/sprite_atlas.dart`: `SpriteAtlas.parse` (reads a
  manifest, throws `FormatException` naming the id) and `problems()` (plain
  checks against the sheet size).
- `lib/core/sprites/sprite_registry.dart`: `SpriteRegistry.load()` reads the
  index, decodes each sheet once, cuts every frame into its own small image and
  frees the sheet. Lookups: `frame(id, [index])` (wraps modulo the frame
  count; null for an unknown id), `frameAt(id, step)` and
  `frameAtProgress(id, t)` (playback, see "Frames and timing"),
  `frameCount(id)`, `stepsPerFrame(id)`, `anchor(id)`, `anchorOf(image)`,
  `has(id)`, `ids`, `loadProblems`. Loading never throws: a broken manifest is
  skipped and reported in `loadProblems` (and `debugPrint`).
  `register(atlas, sheet, idPrefix: 'custom.<name>')` cuts a user upload under
  its own prefix; `unregister` frees it.
- `lib/features/arena_simulation/presentation/power_up_sprites.dart`
  (`PowerUpSprites`): the game's sprite ids and the fitted icons (see "The icon
  special case").
- `lib/features/arena_simulation/presentation/arena_effect_library.dart`: the
  arena effects and their atlas ids (`ArenaEffectDefinition.id`), with frames
  and timing taken from the registry.

### Ids

Ids are `<family>.<name>`:

| Family | Example | Dart helper |
| --- | --- | --- |
| `powerup.<PowerUpKind>` | `powerup.shotgun` | `PowerUpSprites.iconId(kind)` |
| `effect.<EffectSprite>` | `effect.iceWave` | `PowerUpSprites.effectId(kind)` |
| `projectile.<ProjectileSprite>` | `projectile.harpoon` | `PowerUpSprites.projectileId(kind)` |
| `anim.<AnimatedEffect>` | `anim.tornado` | `PowerUpSprites.animId(kind)` |
| one-offs | `projectile.rocketMissile`, `projectile.boomerang`, `effect.omegaTendrilsAttack`, `effect.stickyGooRim` | `PowerUpSprites.rocketMissileId` and friends |

`PowerUpSprites.projectileArtworkId(kind)` gives the shot art a weapon shows
in widgets (null means "use the icon"). `PowerUpSprites.requiredIds` lists
every id the game names; a test checks that each one resolves.

A painter draws a sprite like this:

```dart
final sprite = enabled
    ? SpriteRegistry.frameAtProgress(
        PowerUpSprites.animId(AnimatedEffect.slash),
        progress,
      )
    : null;
if (sprite == null) {
  // draw the vector fallback
}
```

### Frames and timing

Painters never hard-code a frame count or a rate; the manifest's `frames`
and `stepsPerFrame` decide them:

- `SpriteRegistry.frameAt(id, step, {offset})`: looping effects. The index is
  `(step ~/ stepsPerFrame + offset) % frameCount`; `offset` shifts copies of
  one effect (three flames on a ball) so they do not flicker in step.
- `SpriteRegistry.frameAtProgress(id, t)`: one-shot effects that play their
  frames once over their own duration. The index is
  `(t * frameCount).floor().clamp(0, frameCount - 1)`.
- `ArenaEffectLibrary.frame(kind, step)`: the arena effects (finishers,
  lightning, maximum power); looping kinds wrap, the others hold their last
  frame.

Adding frames or changing `stepsPerFrame` in a manifest therefore changes
every call site at once. A few call sites keep an older, slower look and pass
an explicit override (`frameAt(..., stepsPerFrame: 4)`), because
`ArenaEffectLibrary` plays the same sprite at the manifest rate:

| Sprite | Manifest | Override | Where |
| --- | --- | --- | --- |
| `anim.campfire` | 3 | 4 | burning zones, fire walls (`PowerUpPainter._campfireStepsPerFrame`) |
| `anim.portal` | 3 | 4 | portal and swap flashes, rim portals (`_portalStepsPerFrame`) |
| `anim.flame` | 3 | 4 | flames on a burning ball (`_burningFlameStepsPerFrame`) |
| `anim.tornado` | 3, 8 frames | 1 frame per 1/24 of the hook, first 4 frames only | the tornado finisher in `harpoon_cinematic.dart` (`stepsPerFrame: 1, frameCount: 4`) |

### Anchor

Every sprite has an anchor, the point of its image (0 to 1 per axis, from the
top left) that is put on the painter's target point; it is also the point the
sprite turns around. The painter helpers (`_drawSprite` and `_drawEffect` in
`PowerUpPainter`, `_paintRaster` in `HarpoonCinematic`) read it with
`SpriteRegistry.anchorOf(image)` and place the image with
`SpriteRegistry.placeRect`, so a manifest anchor works without touching call
sites. With the default center the rectangle is exactly the old
`Rect.fromCenter`. Every bundled sprite uses the center today. Drawing code of
its own (the sticky goo rim slices, `LightningStrikePainter`, which puts the
strike's foot at 88 percent of the frame height, and the widget icons) does
not read the anchor.

Rules for painters:

- Look the frame up with an id from a helper or a `const`. The helpers return
  strings built once per app, so painting never formats strings. Never write
  `'anim.${kind.name}'` in a paint method.
- Keep the render-mode switch (`enabled` above, from
  `usesEffectSprite` / `usesSprite` / the admin's Sprite or Vector setting)
  in front of the lookup, so the Vector look still skips sprites.
- Every lookup can return null (before `load()` finishes, and in tests that
  skip it), so always keep a vector fallback.
- Draw with `FilterQuality.none`.

## Sheet rules

- The background is fully transparent. No baked-in checkerboard, shadow plate
  or colored backdrop.
- Every frame has a 2 px clear border inside its rectangle: no pixel with
  alpha above 24 in its outer 2 px. Then neighboring art can never bleed into
  a cut frame. `atlas_isolation_test.dart` checks it.
- Edit sheets only with PhotoCraft,
  `C:\Program Files\PhotoCraft\photocraft-cli.exe` (see `AGENTS.md`). Read-only
  inspection (Pillow in `make_atlas.py`, the tests) is fine.
- A changed sheet gets a new file name (for example
  `tornado-animated-v2.png`). Never overwrite an original sheet; point the
  manifest at the new file instead.
- No AI image generation. Art is drawn by hand or composed in PhotoCraft.

## Manifest fields

```json
{
  "sheet": "assets/sprites/effects-animated.png",
  "sprites": {
    "anim.explosion": {
      "frames": [
        [8, 215, 346, 183],
        [370, 212, 346, 201],
        [732, 213, 346, 200],
        [1094, 215, 346, 197]
      ],
      "output": 96,
      "fit": "contain",
      "sharedBand": true,
      "padding": 3,
      "stepsPerFrame": 2,
      "bleedOk": false
    }
  }
}
```

| Field | Default | Meaning |
| --- | --- | --- |
| `sheet` | required | Asset path of the PNG, from the repo root. |
| `sheetSize` | none | `[width, height]` of the sheet in px. When given, a decoded sheet of another size is a problem (`<sheet> is WxH, the manifest expects WxH`), so a replaced or resized sheet is caught instead of cut wrong. Every bundled manifest sets it; `make_atlas.py` writes it. |
| `sprites` | required | Object of sprite id to definition. |
| `frames` | required | List of `[x, y, width, height]` in sheet pixels; decimals allowed (`443.5`). Frames play in list order and must not overlap. |
| `output` | required | Width of each cut image in px (its side when square). |
| `outputHeight` | `output` | Height of the cut image when it is not square (the goo rim is 768 x 160). |
| `fit` | `"contain"` | `contain`: scale the frame to fit inside the output minus `padding`, keeping its shape, centered. `trim` (two steps): contain the frame into the whole output canvas (minus `trimCutPadding`, 0 by default), measure the visible art (alpha >= 16) on that cut, then contain those bounds into the output minus `padding` on a fresh canvas. The art then fills the box whatever margin the sheet cell has. A fully transparent frame stays the plain cut. Every icon uses it. `fill`: stretch the frame to the whole output box (for strips). |
| `padding` | `2` | Transparent px kept on each side of the output image. Must leave room: `2 * padding` smaller than both output sides. |
| `trimCutPadding` | `0` | Fit `trim` only: the margin of the first cut, the one that is measured. Only the four `phase8-skills` icons set it (2), because they were cut into 60 px before the refit and must keep those exact pixels. |
| `sharedBand` | `false` | All frames share one scale and keep their vertical offsets inside the band that covers every frame, so an animation does not jump or pulse. Needs a square output and cannot be combined with `fill` or `trim`. |
| `stepsPerFrame` | `4` | Simulation steps (1/60 s) each frame is shown. `frameAt` and `ArenaEffectLibrary` read it together with the frame count, so changing either in the manifest changes the game; only the call sites listed under "Frames and timing" override the rate. |
| `anchor` | `[0.5, 0.5]` | The point of the output image, 0 to 1 per axis, that painters put on their target point (see "Anchor"). The cut itself does not change. |
| `bleedOk` | `false` | The frame may touch neighboring art; the isolation test skips it. |
| `bleedNote` | none | Why bleeding is fine. Required when `bleedOk` is true. |

`problems()` reports, in plain words: no frames, a frame with no area or
outside the sheet, overlapping frames, padding that leaves no room,
`sharedBand` without a square output, `fill` or `trim` with `sharedBand`,
`trimCutPadding` without fit `trim` or without room, an anchor outside 0 to 1,
a sheet whose size differs from `sheetSize`, and `bleedOk` without a
`bleedNote`. The registry skips any manifest with problems (at load, with a
`loadProblems` entry); `register` throws `ArgumentError` for them.

## The index file

`assets/sprites/atlas-index.json` is a plain JSON list of manifest paths. A
manifest that is not listed is never loaded. Each sprite id may appear in only
one manifest: when two manifests name the same id, the first one in the index
wins and the clash goes to `loadProblems`. `pubspec.yaml` already bundles the
whole `assets/sprites/` folder.

## make_atlas.py

`tool/sprites/make_atlas.py` (Python 3, Pillow) measures frames from a sheet's
alpha channel and writes a manifest. It only reads the sheet. Run it from the
repo root so `sheet` is the asset path. Rows and columns count from 0.

Measured grid (the default). Each frame starts as its grid cell, every edge
moves to the nearest fully clear row or column, then out by up to `--margin`
px (default 2) over clear lines, so the frame keeps its 2 px border:

```bash
python tool/sprites/make_atlas.py --sheet assets/sprites/acid-splash.png \
    --grid 4x1 --id-row 0=anim.acidSplash --out assets/sprites/acid-splash.atlas.json
```

Several rows into one sprite (`0-1` takes rows 0 and 1, row by row, left to
right), cut as exact cells; this reproduces the bundled tornado manifest:

```bash
python tool/sprites/make_atlas.py --sheet assets/sprites/tornado-animated-v2.png \
    --grid 4x2 --id-row 0-1=anim.tornado --exact --inset 12 --padding 2 \
    --steps-per-frame 3 --out assets/sprites/tornado-animated-v2.atlas.json
```

Several sprites from one sheet, one per row, with a fixed cell size:

```bash
python tool/sprites/make_atlas.py --sheet assets/sprites/goo-effects.png \
    --grid 4x2 --cell 443.5x443.5 --id-row 0=anim.gooSplash --id-row 1=anim.gooDrip \
    --shared-band --out assets/sprites/goo-effects.atlas.json
```

Single frames at given rectangles (icons and one-offs), as on the rocket sheet:

```bash
python tool/sprites/make_atlas.py --sheet assets/sprites/rocket-launcher.png \
    --grid 1x1 --output 64 --padding 0 \
    --icons powerup.rocketLauncher=0,0,887,887 \
    --out assets/sprites/rocket-launcher.atlas.json
```

Options:

- `--grid COLSxROWS` (required): the grid. The cell is the sheet size divided
  by it (the tool warns when it does not divide evenly).
- `--cell WxH`: a fixed cell size, decimals allowed, e.g. `--cell 443.5x443.5`
  for a sheet whose cells are not a whole fraction of it.
- `--exact` with `--inset N`: frames are the grid cells inset by N px on every
  side, with no measuring. Use it to reproduce an existing hand cut exactly,
  e.g. `--grid 4x6 --cell 362x181 --exact --inset 10`.
- `--padding N` and `--steps-per-frame N`: written into every sprite when given.
- `--fit contain|trim|fill` (default `contain`): written into every sprite,
  icons included (icons use `--fit trim`). `trim` and `fill` cannot be
  combined with `--shared-band`; the tool refuses with exit status 1.
- `--shared-band`: only sets the flag; frames keep their own rectangles.
- `--icons ID=x,y,w,h ...`: single-frame sprites at given rectangles. They all
  share `--output`, so a sheet whose sprites need different sizes (the rocket
  sheet has a 64 px icon and a 96 px missile) gets its other sizes by hand.
- `--force`: overwrite `--out` when it already exists. Without it the tool
  refuses, prints an error to stderr and exits with status 1.
- `--output N`: output size (default 96; icons use 64).
- `--margin N`: how far an edge may move out over clear lines (default 2).
- `--max-shift N`: how far an edge may move to find a clear line (default
  100). An edge with no clear line in reach stays on the grid line and the tool
  prints a warning to stderr.

The manifest always gets the sheet's real `sheetSize`. The tool never writes
`bleedOk: true`, `bleedNote`, `outputHeight`, `anchor` or `trimCutPadding`;
add those by hand. Its own tests:
`python tool/sprites/test_make_atlas.py`.

## Tests

- `test/core/sprites/sprite_atlas_test.dart` and `sprite_registry_test.dart`:
  the parser, `problems()` (anchor, `sheetSize`), the cutting rules, the
  playback helpers and anchors, on small fake sheets.
- `test/features/arena_simulation/presentation/sprite_anchor_painter_test.dart`:
  the painter puts a sprite's anchor on its target point, and
  `PowerUpSprites.load()` registers the drawn icons again after a reset.
- `test/core/sprites/atlas_isolation_test.dart`: every frame of every bundled
  sheet has a clear 2 px border (alpha above 24 fails). Sprites with `bleedOk`
  are skipped. Failures name sheet, id and frame.
- `test/core/sprites/bundled_atlas_test.dart`: every bundled manifest loads
  with no problems and names its `sheetSize`, every id in `PowerUpSprites.requiredIds` and
  `ArenaEffectLibrary` resolves, each sheet is decoded once, and the frame
  counts, sizes and timing match the game.
- `test/core/sprites/sprite_goldens_test.dart`: contact sheets of every
  family (`test/core/sprites/goldens/*.png`). The comparator accepts up to
  0.1% differing pixels, because the goldens are made on Windows and CI runs
  on Linux.

### Updating goldens responsibly

A golden failure means pixels changed. When the change is meant (a new
sprite, a fixed cut):

1. Run `flutter test test/core/sprites/sprite_goldens_test.dart` and read the
   failure images Flutter writes next to the goldens (`failures/`).
2. Check that only the sprites you touched differ.
3. Run `flutter test test/core/sprites/sprite_goldens_test.dart --update-goldens`,
   open the new PNGs, and say in the commit message which sprites changed and
   why.

Never update goldens to quiet a refactor that was meant to change nothing.
Find the difference instead.

## Icons and sprites drawn in code

Icons are plain registry frames: `PowerUpSprites.of(kind)` is
`SpriteRegistry.frame(PowerUpSprites.iconId(kind))`. Every `powerup.<kind>`
entry uses `"fit": "trim"`, `"padding": 2` and `"output": 64`, so its visible
art fills 60 px inside a 2 px border. Only the fitted frame is kept.

Kinds without sheet art (`PowerUpSprites.pixelArtOnly`: vampire and repulsor)
are drawn in code from their 16 x 16 pixel art (`power_up_pixel_art.dart`)
and added by `PowerUpSprites.load()` with:

```dart
await SpriteRegistry.registerDrawn(
  'powerup.vampire',
  image,               // the caller keeps it and may dispose it afterwards
  fit: SpriteFit.trim, // same fits as a manifest; contain by default
  output: 64,          // outputHeight, padding (2), stepsPerFrame optional
);
```

`registerDrawn` puts the whole image through the same fit as a manifest frame
and stores its own copy as one bundled sprite (one frame). It has no
`trimCutPadding` (its trim measures a cut of the whole output, cut padding
0) and takes an optional `anchor` (center by default). It throws
`ArgumentError` for `custom.` ids (those belong to `register`), ids already in
use and sizes the manifest rules reject. A manifest that later names the same
id is skipped with a load problem. `resetForTest` while it runs discards the
result, like `load`; `PowerUpSprites.load()` registers the drawn icons again
after each new registry load; it only tolerates the `ArgumentError` of an id
another load registered meanwhile and rethrows any other. `paintIcon` still draws the pixel art (or an
initials badge) directly for widgets while the image is null, and
`PowerUpIcon` is the widget for both.

## Worked example: a new acid splash effect

1. Draw the frames in PhotoCraft on a transparent sheet, one row of four
   cells, each frame with at least a 2 px clear border. Save it as
   `assets/sprites/acid-splash.png`.
2. Write the manifest:

   ```bash
   python tool/sprites/make_atlas.py --sheet assets/sprites/acid-splash.png \
       --grid 4x1 --id-row 0=anim.acidSplash --shared-band --steps-per-frame 3 \
       --out assets/sprites/acid-splash.atlas.json
   ```

   Read the warnings. A missing clear edge means the art touches its cell
   border; fix the sheet (as a new file) rather than setting `bleedOk`.
3. Add `"assets/sprites/acid-splash.atlas.json"` to `atlas-index.json`.
4. Add `acidSplash` to `AnimatedEffect` in `power_up_sprites.dart`. Its id
   `anim.acidSplash` comes from `animId`, and `requiredIds` now includes it,
   so `bundled_atlas_test.dart` fails until the manifest is in place.
5. Draw it in `PowerUpPainter`, behind the render-mode switch and with a vector
   fallback:

   ```dart
   final splash = useSprite
       ? SpriteRegistry.frameAt(
           PowerUpSprites.animId(AnimatedEffect.acidSplash),
           age,
         )
       : null;
   ```

   (`frameAtProgress(id, t)` instead for a splash that plays once.)

   (If it is an arena effect, add an `ArenaEffectKind` with
   `ArenaEffectDefinition(id: 'anim.acidSplash')` instead and let
   `ArenaEffectLibrary.frame` do the timing.)
6. Run `flutter test test/core/sprites/`. The isolation and bundled tests must
   pass. The `animated_effect_frames` golden fails because it gained a row:
   check that only the new row differs, then update the goldens as above.
7. Run `flutter test tool/bench/paint_bench_test.dart` and compare with the
   numbers before your change. Then `flutter analyze` and `flutter test`.

## Known issues

- Some bundled sprites set `bleedOk`, all to keep the look from before the
  atlases (the old cuts clipped art, and re-cutting them is a visual change for
  later). Their `bleedNote` gives the details:
  - `effects-animated`: `anim.flame`, `anim.slash`, `anim.blood` (the rows of
    that sheet overlap, so the art runs past the 10 px inset cells) and
    `anim.iceImpact` (frame 3 starts inside a 17 px tail of the portal art).
  - `effects-master`: nine `effect.*` cells cut at the 362 px cell inset by
    12 px, whose art reaches into the inset.
  - `projectiles-master`: `projectile.shotgun` and `projectile.gatling`, whose
    glow crosses their shared cell line (about 1 px clipped).
  - `elemental-powers`: `powerup.waterGun` (its stream tip crosses into the
    next cell) and `powerup.lightningStrikes` (shows that tip on its left
    edge).
  - `sticky-goo-rim`: `effect.stickyGooRim` is a strip that runs to the
    sheet's left and right edges on purpose; the cut also clips the last 5
    rows of the drips.
- The goldens draw every sprite downsampled into an 88 px cell (a 96 px cell
  less 4 px on each side). Small cut changes on large sprites, such as a few
  rows of the 768 px goo rim or of the 192 px lightning frames, can fall below
  what that shows, so check those by eye in the game as well.
- `SpriteRegistry.resetForTest()` after `PowerUpSprites.load()` leaves the
  facade's cached icons and future in place for that test isolate.
