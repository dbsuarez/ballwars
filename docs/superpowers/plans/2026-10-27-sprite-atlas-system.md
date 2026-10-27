# Sprite Atlas System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-cut sprite code in `PowerUpSprites` (948 lines, 18 sheets, about 75 magic rectangles and constants) with a data-driven atlas: one manifest per sheet describing its sprites, one loader, one lookup API, and a test that catches art bleeding between frames, so adding or fixing a sprite means editing a manifest, not code.

**Architecture:** Each sheet in `assets/sprites/` gets a JSON manifest (`<sheet>.atlas.json`) naming its sprites (`powerup.pistol`, `effect.explosion`, `projectile.bow`, ...) with their frame rectangles in sheet pixels, frame timing and output size. `SpriteRegistry` (in `lib/core/sprites/`) loads every manifest listed in `assets/sprites/atlas-index.json`, decodes each sheet once, cuts the frames into small `ui.Image`s (nearest-neighbor, like today) and answers `frame(id, n)`. `PowerUpSprites` keeps its public methods during the migration and becomes a thin facade over the registry, so painter, cinematic, exporter and battle screen do not change until the last task. A Python tool reads a sheet's alpha channel (read-only) and writes manifest rectangles trimmed to clean rows/columns, the way the explosion and ice bands were measured by hand.

**Tech Stack:** Flutter/Dart (`dart:ui` image decode, `rootBundle`), JSON manifests, Python 3 + Pillow for the read-only atlas tool, flutter_test goldens.

**Follow-up:** `docs/superpowers/plans/2026-10-27-sprite-editor.md` (the in-app Sprite Editor) builds on this plan; Task 4's runtime `register` API exists for it.

**Spec:** No separate spec. Requirements come from the owner (2026-10-27: "the sprites are making a mess with the code, we should have a working sprite system"), the current code (`lib/features/arena_simulation/presentation/power_up_sprites.dart`, `sprite_asset_pipeline.dart`, `arena_effect_library.dart`) and the asset rules in `AGENTS.md` and `docs/PHOTOCRAFT-CLI-HANDOFF.md`.

## Global Constraints

- No AI image generation or editing. Raster edits only with PhotoCraft (`C:\Program Files\PhotoCraft\photocraft-cli.exe`, helpers in `tools/photocraft/`); originals are never overwritten, edited sheets get new file names.
- The atlas tool only reads images (Pillow) and writes JSON; it never writes pixels.
- Rendering only: no change to the simulation, its RNG draws, determinism, replay links or match outcomes.
- Web-safe: assets load with `rootBundle`; no `dart:io` in `lib/`.
- Pixel art stays crisp: frames are cut and drawn with `FilterQuality.none`.
- Sprite images are built once at load (like today); no per-frame decoding or cutting.
- A missing sprite never crashes a match: lookups return null and callers keep their vector glyph fallback (current behavior).
- UI text never uses en or em dashes.

## Review Focus

- A manifest id that code asks for but no manifest defines (typo, renamed sheet): `frame()` returns null, the vector fallback draws, and the validation test fails in CI.
- A sheet that fails to decode on one platform (web Cache Storage, Android asset path): `SpriteRegistry.load()` still completes, other sheets still work, the failure is logged once.
- Art bleeding across frame edges (the explosion/ice problem): the isolation test flags any frame whose 2 px border is not transparent unless the manifest marks it `"bleedOk": true` with a reason.
- Skill artwork tint (`SkillArtworkTint`) and per-skill scale still apply identically to registry images: golden contact sheets match before and after.
- Load time on low-end phones does not grow: total sheets decoded stay the same; the registry test reports load time against the old loader.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/sprites/sprite_atlas.dart` (new) | Pure model: `SpriteAtlas`, `SpriteDef`, JSON parse and structural validation. No Flutter imports beyond `dart:ui` geometry. |
| `lib/core/sprites/sprite_registry.dart` (new) | Loads `atlas-index.json` and manifests, decodes sheets, cuts frames, lookup API. |
| `assets/sprites/atlas-index.json` (new) | List of manifest paths. |
| `assets/sprites/*.atlas.json` (new, one per sheet) | Sprite ids, frame rectangles, timing, output size. |
| `tool/sprites/make_atlas.py` (new) | Read-only: grid spec in, trimmed frame rectangles out (JSON). |
| `lib/features/arena_simulation/presentation/power_up_sprites.dart` | Shrinks to a facade, then to id helpers. |
| `lib/features/arena_simulation/presentation/arena_effect_library.dart` | Maps effect kinds to atlas ids. |
| `lib/features/arena_simulation/presentation/sprite_asset_pipeline.dart` | Removed at the end (its grid loading moves into the registry). |
| `test/core/sprites/` (new) | Model, registry, isolation and golden tests. |
| `docs/SPRITES.md` (new) | How to add or fix a sprite. |

## Atlas manifest format (decided)

```json
{
  "sheet": "assets/sprites/effects-animated.png",
  "sprites": {
    "effect.explosion": {
      "frames": [[8, 218, 346, 196], [370, 218, 346, 196], [732, 218, 346, 196], [1094, 218, 346, 196]],
      "anchor": [0.5, 0.5],
      "output": 96,
      "fit": "contain",
      "stepsPerFrame": 4,
      "sharedBand": true
    }
  }
}
```

- `frames`: `[x, y, width, height]` in sheet pixels, one per frame (at least 1).
- `output`: square size in px of each cut image (64 for icons, 96 for effects and projectiles today).
- `fit`: `contain` (scale to fit, centered) or `trim` (crop to visible alpha first, then contain; replaces `fitVisibleArtwork`).
- `sharedBand`: when true, every frame is scaled by the same factor and placed on one shared origin so animations do not jump (what `_iceRows` does today); otherwise each frame is fitted on its own.
- `stepsPerFrame` (optional, default 4): animation speed in simulation steps.
- `bleedOk` (optional) plus `"bleedNote"`: allows a frame border that is not transparent; the note is required.

---

### Task 1: Golden reference of today's sprites

**Files:**
- Create: `test/core/sprites/sprite_goldens_test.dart`
- Create: `test/core/sprites/goldens/*.png` (generated)

**Interfaces:**
- Consumes: today's `PowerUpSprites.load()`, `of`, `effect`, `projectile`, `projectileArtwork`, `effectFrame`, `rocketMissile`, `omegaTendrilsAttack`, `boomerangProjectile`, `stickyGooRim`.
- Produces: golden files that Tasks 5 and 6 must keep matching.

- [ ] **Step 1: Write `sprite_goldens_test.dart`**: inside `tester.runAsync`, load sprites, draw contact sheets (one per family: power-up icons for every `PowerUpKind`, every `EffectSprite`, every `ProjectileSprite`, every frame of every `AnimatedEffect`, the special getters) on a fixed background, and `expectLater(..., matchesGoldenFile('goldens/<family>.png'))`.
- [ ] **Step 2: Generate**: `flutter test test/core/sprites/sprite_goldens_test.dart --update-goldens`. Expected: PASS, 5 PNGs written.
- [ ] **Step 3: Inspect each golden** (open the PNGs) and note any sprite that already looks wrong in `docs/SPRITES.md` (Task 7) as a known issue; do not fix it here.
- [ ] **Step 4: Run without `--update-goldens`**. Expected: PASS.
- [ ] **Step 5: Commit** `test: golden contact sheets of every current sprite`.

### Task 2: Atlas model and validation

**Files:**
- Create: `lib/core/sprites/sprite_atlas.dart`
- Test: `test/core/sprites/sprite_atlas_test.dart`

**Interfaces:**
- Produces:
  - `enum SpriteFit { contain, trim }`
  - `class SpriteDef { final String id; final List<Rect> frames; final Offset anchor; final int output; final SpriteFit fit; final bool sharedBand; final int stepsPerFrame; final bool bleedOk; }`
  - `class SpriteAtlas { final String sheet; final Map<String, SpriteDef> sprites; static SpriteAtlas parse(Object? json); List<String> problems({required Size sheetSize}); }`
  - `parse` throws `FormatException` with the sprite id in the message for malformed input.
  - `problems` returns plain-language messages: a frame outside the sheet, an empty frame list, overlapping frames inside one sprite, a `bleedOk` without `bleedNote`, a duplicate id.

- [ ] **Step 1: Write failing tests**: `parses the documented example`; `rejects frames outside the sheet` (expects a problem naming `effect.explosion` and frame 2); `rejects bleedOk without a note`; `defaults stepsPerFrame to 4 and fit to contain`; `malformed rect throws FormatException mentioning the id`.
- [ ] **Step 2: Run**: `flutter test test/core/sprites/sprite_atlas_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement** `sprite_atlas.dart` with the interfaces above.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sprites): atlas manifest model and validation`.

### Task 3: Atlas tool (read-only)

**Files:**
- Create: `tool/sprites/make_atlas.py`
- Test: `tool/sprites/test_make_atlas.py` (stdlib `unittest`, synthetic PNGs made with Pillow in a temp dir)

**Interfaces:**
- Produces: CLI `python tool/sprites/make_atlas.py --sheet assets/sprites/X.png --grid COLSxROWS --id-row 1=effect.explosion --id-row 3=effect.ice-impact [--shared-band] --out assets/sprites/X.atlas.json`.
  - For each requested row, per column: start from the grid cell, then move each edge outward/inward to the nearest fully transparent pixel row/column (alpha <= 24) that separates this art from the neighboring cell's art, exactly the measurement used for `_explosionTop` / `_iceRows`.
  - Prints a warning (and writes `"bleedOk": false`) for a frame with no clean edge within 40 px.
  - `--icons ID=x,y,w,h ...` for irregular single sprites.
- Never writes image files.

- [ ] **Step 1: Write failing tests**: a synthetic 2x2 sheet whose top-left art leaks 10 px into the cell below; the tool returns a top-left rect ending at the clean row and the bottom-left rect starting after it; a cell with no clean edge yields a warning.
- [ ] **Step 2: Run**: `python -m unittest tool/sprites/test_make_atlas.py`. Expected: FAIL.
- [ ] **Step 3: Implement** `make_atlas.py`.
- [ ] **Step 4: Run** the same command. Expected: PASS. Then run it on `effects-animated.png` rows 1 and 3 and check the output matches today's `_explosionTop`/`_explosionHeight` and `_iceRows` within 2 px.
- [ ] **Step 5: Commit** `tool(sprites): read-only atlas generator from sheet alpha`.

### Task 4: Sprite registry and isolation test

**Files:**
- Create: `lib/core/sprites/sprite_registry.dart`
- Create: `assets/sprites/atlas-index.json` (empty list `[]` for now)
- Modify: `pubspec.yaml` (declare `assets/sprites/` if not already listed, including `.json`)
- Test: `test/core/sprites/sprite_registry_test.dart`, `test/core/sprites/atlas_isolation_test.dart`

**Interfaces:**
- Consumes: `SpriteAtlas.parse`, `SpriteDef` (Task 2).
- Produces:
  - `class SpriteRegistry { static Future<void> load({AssetBundle? bundle}); static Future<void> register(SpriteAtlas atlas, ui.Image sheet, {required String idPrefix}); static void unregister(String idPrefix); static ui.Image? frame(String id, [int index = 0]); static int frameCount(String id); static int stepsPerFrame(String id); static bool has(String id); static List<String> get ids; static List<String> get loadProblems; }`
  - `register` cuts an already decoded sheet (the Sprite Editor's uploads) under ids `<idPrefix>.<sprite id>`; registering the same prefix again replaces its sprites; bundled ids can never be replaced (`idPrefix` must start with `custom.`).
  - `load` is idempotent (same future), reads the index, decodes each sheet once, cuts frames per `SpriteDef` (contain / trim / sharedBand), records a problem and skips the sheet when decoding fails, never throws.
  - `frame` wraps `index` modulo `frameCount` (like `effectFrame` today) and returns null for unknown ids.

- [ ] **Step 1: Write failing tests**:
  - registry with a test bundle (`FakeAssetBundle` serving a generated 2-frame PNG and its manifest): `frameCount == 2`, `frame('x', 3)` returns frame 1, `frame('missing')` is null, a corrupt sheet adds one `loadProblems` entry and other sheets still load;
  - `register` with `idPrefix: 'custom.abc'` adds `custom.abc.flame`; registering again replaces it; `unregister('custom.abc')` removes it; `register` with prefix `effect` throws `ArgumentError`;
  - isolation test: for every manifest in the real index, decode the sheet (read pixels via `toByteData`) and assert each frame's 2 px border is transparent (alpha <= 24) unless `bleedOk`; failure message lists sheet, id and frame.
- [ ] **Step 2: Run**: `flutter test test/core/sprites/`. Expected: FAIL.
- [ ] **Step 3: Implement** `sprite_registry.dart` with the interfaces above; reuse the cutting code from `SpriteAssetPipeline.load`.
- [ ] **Step 4: Run** the same command. Expected: PASS (the isolation test passes trivially with an empty index).
- [ ] **Step 5: Commit** `feat(sprites): registry loader and frame isolation test`.

### Task 5: Migrate the grid sheets

**Files:**
- Create: `assets/sprites/powerups-fixed.atlas.json`, `effects-master.atlas.json`, `projectiles-master.atlas.json`, `effects-animated.atlas.json`
- Modify: `assets/sprites/atlas-index.json`, `lib/features/arena_simulation/presentation/power_up_sprites.dart`

**Interfaces:**
- Consumes: `SpriteRegistry` (Task 4), `make_atlas.py` (Task 3).
- Produces: ids `powerup.<PowerUpKind.name>`, `effect.<EffectSprite.name>`, `projectile.<ProjectileSprite.name>`, `anim.<AnimatedEffect.name>`. `PowerUpSprites.of/effect/projectile/effectFrame` delegate to `SpriteRegistry.frame` with these ids; `PowerUpSprites.load()` calls `SpriteRegistry.load()`.

- [ ] **Step 1: Generate manifests** with `make_atlas.py` (grids: powerups-fixed 8 columns of 128 px from `_sheetRects`; effects-master 4x3 cells of 362 px inset 12; projectiles-master 4x2 cells of 443.5 px; effects-animated 4 columns x 6 rows of 362x181 px, explosion and ice with `--shared-band` as today). Copy `_sheetRects` rectangles for icons verbatim.
- [ ] **Step 2: Run the isolation test**: `flutter test test/core/sprites/atlas_isolation_test.dart`. Expected: PASS; fix any flagged frame by re-measuring, or mark `bleedOk` with a note.
- [ ] **Step 3: Switch the four sheets' loading in `PowerUpSprites` to the registry**; delete their hand-cutting code, `_sheetRects`, `_explosionTop`, `_explosionHeight`, `_iceRows`.
- [ ] **Step 4: Run goldens and everything**: `flutter test test/core/sprites/ && flutter test`. Expected: PASS; goldens match (if a golden differs only because an old frame had bleed, inspect, then update that golden with `--update-goldens` and say why in the commit).
- [ ] **Step 5: Commit** `refactor(sprites): grid sheets load from atlas manifests`.

### Task 6: Migrate the one-off sheets

**Files:**
- Create: `*.atlas.json` for `molotov-campfire`, `arena-portal`, `maximum-power`, `tornado-animated-v2`, `lightning-strike-8`, `phase8-skills`, `rocket-launcher`, `omega-tendrils`, `boomerang`, `sticky-goo-rim`, `elemental-powers`, `earth-wind`, `energy-wave`, `flamethrower`
- Modify: `power_up_sprites.dart`, `arena_effect_library.dart`; delete `sprite_asset_pipeline.dart` and move its test cases into `sprite_registry_test.dart`

**Interfaces:**
- Produces: ids such as `powerup.rocketLauncher`, `projectile.rocketMissile`, `effect.omegaTendrilsAttack`, `projectile.boomerang`, `effect.stickyGooRim`, `anim.campfire`, `anim.portal`, `anim.maximumPower`, `anim.tornado`, `anim.lightning`. `fit: "trim"` replaces `fitVisibleArtwork` where it is used today (rocket launcher, omega tendrils, boomerang icons).

- [ ] **Step 1: Generate or hand-write manifests** (one-off sheets usually need `--icons`); take today's rectangles from `power_up_sprites.dart` where they exist.
- [ ] **Step 2: Run the isolation test**. Expected: PASS or documented `bleedOk`.
- [ ] **Step 3: Point the special getters (`rocketMissile`, `omegaTendrilsAttack`, `boomerangProjectile`, `stickyGooRim`) and `ArenaEffectLibrary.definitions` at registry ids**; remove the remaining hand-cutting code and `SpriteAssetPipeline`.
- [ ] **Step 4: Run goldens and everything**: `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `refactor(sprites): every sheet loads from the atlas; SpriteAssetPipeline removed`.

### Task 7: Callers use ids; docs

**Files:**
- Modify: `power_up_painter.dart`, `harpoon_cinematic.dart`, `arena_battle_screen.dart`, `replay_video_exporter.dart`, `power_up_sprites.dart`
- Create: `docs/SPRITES.md`
- Modify: `CLAUDE.md` (Drawing paragraph)

**Interfaces:**
- Consumes: `SpriteRegistry.frame/frameCount/stepsPerFrame` (Task 4).
- Produces: `PowerUpSprites` reduced to id helpers (`static String iconId(PowerUpKind)`, `static String projectileId(PowerUpKind)`) plus `paintIcon` for the pixel-art fallback; the special getters are removed.

- [ ] **Step 1: Replace each `PowerUpSprites.<getter>` call with `SpriteRegistry.frame(<id>)`** (grep shows 14 `effectFrame`, 9 `projectile`, 8 `of`, 8 `effect`, plus the special getters).
- [ ] **Step 2: Write `docs/SPRITES.md`**: sheet rules (transparent background, 2 px clear border, PhotoCraft for edits, new file names), manifest fields, running `make_atlas.py`, the isolation and golden tests, and a worked example (adding a new effect end to end).
- [ ] **Step 3: Update `CLAUDE.md`** Drawing paragraph to describe the atlas, registry and docs.
- [ ] **Step 4: Run** `flutter analyze` (no issues), `flutter test` (all pass, goldens unchanged), `flutter test tool/bench/paint_bench_test.dart` (paint timings no worse than before; note the numbers in the commit).
- [ ] **Step 5: Commit** `refactor(sprites): callers use atlas ids; sprite docs`.
