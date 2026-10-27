# Ball Wars sprite asset standard

All bundled sprites are cut by `SpriteRegistry` (`lib/core/sprites/`) from an
atlas manifest next to the sheet (`assets/sprites/<sheet>.atlas.json`, listed
in `assets/sprites/atlas-index.json`); do not add one-off atlas cropping to a
painter. `python tool/sprites/make_atlas.py` measures or copies frame
rectangles into a manifest, and `test/core/sprites/atlas_isolation_test.dart`
checks that every frame keeps a transparent 2 px border.

## Required layout

- Use a fixed rectangular grid, and list every frame's rectangle in the
  manifest; the registry rejects frames that fall outside the sheet.
- Keep the subject centered on one stable anchor in every frame.
- Reserve a transparent safe area inside every cell, and keep frame
  rectangles inside it, so pixels can never bleed from a neighbor.
- Use a genuinely transparent RGBA canvas. Do not use white, black,
  checkerboard, glow-box, or other rectangular cell backgrounds.
- Put one animation frame in every cell, ordered left-to-right and then
  top-to-bottom. Loops must return cleanly from the last frame to the first.
- Use lowercase kebab-case names: `<effect>-animated-vN.png` for animation
  sheets and `<item>-vN.png` for single-frame artwork.
- Keep the entire effect inside its cell, including glow, smoke, sparks, and
  antialiasing. No pixel may rely on content from another cell.
- Add new bundled artwork through a manifest, then paint only the isolated
  images returned by `SpriteRegistry.frame`.

The Phase 7 Tornado sheet is `1760x880`: four columns by two rows, with eight
`440x440` frames, cut with a 12-pixel inset (`tornado-animated-v2.atlas.json`).

## External lightning-generation prompt

```text
Create a production 2D game-VFX sprite sheet for Ball Wars containing exactly
8 sequential lightning-strike frames in a strict 4-column by 2-row grid. The
final PNG must be exactly 1760x880 pixels; every cell is exactly 440x440.
Center one vertical white/yellow/cyan lightning bolt in every cell. Show a
seamless sequence: charge glow, descending fork, ground impact, branching
flash, and fading sparks. Preserve one stable ground-contact anchor. Keep all
pixels, glow, branches, and sparks at least 16 pixels inside their own cell.
Use crisp colorful 16-bit arcade pixel-art readable at 64px. Output genuine
RGBA transparency. No text, labels, borders, grid lines, shadows, rectangular
backgrounds, clipping, overlapping cells, or neighboring-cell bleed.
```
