# Sprite Importer ("Sprite Editor") Implementation Plan

## Execution status (2026-10-28)

The first importer is implemented. The current owner guide and grouped remaining
work are in [SPRITES.md](../../SPRITES.md); the checklist below preserves the
original implementation recipe rather than a production acceptance claim.

- [x] Single PNG/WebP icons, animated grids or separate grid icons.
- [x] Aseprite hash/array and TexturePacker JSON, trimmed canvas offsets,
  rotation rejection and transparent-edge isolation checks.
- [x] Owner-requested pre-upload optimization: icon/held frames at most 128 px;
  projectile/effect frames at most 256 px. Original files preserved.
- [x] Admin storage/repository, offline cache and background registration.
- [x] Full/compact skill sprite slots, editor pickers, arena and finisher rendering.
- [x] Tabbed importer, animation preview, checkerboard, background warning,
  affected-skill deletion confirmation, visible save failures and retry.
- [x] Migration is **023_sprite_atlases.sql**, not the originally proposed 022.
  User confirmed it ran in Supabase on 2026-10-28.
- [ ] Browser/Android/cross-device and offline production acceptance.
- [x] Replace an atlas in place with stable-ID mapping, removal warnings and
  optimistic concurrency protection; no additional migration required.
- [x] Add `.bwsprites` export/restore with original IDs, integrity validation,
  contents/conflict preview and partial-failure retries.
- [x] Add library and picker search/filter plus human-readable upload names.
- [x] Complete per-sprite names/frame order/timing/anchors, frame diagnostics and
  blank-frame controls, preview backgrounds/ball colors and smooth resizing with
  actual optimized comparison. Existing atlas metadata can be edited directly.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the admin attach new sprite artwork to the game from inside the app: upload a sheet (with an Aseprite or TexturePacker JSON when there is one), slice it, preview it on the real arena, and attach it to a skill's icon / held weapon, its projectile, its impact effect, or a built-in's artwork. Everyone then sees it in matches, replays and videos.

**Architecture:** Drawing and animating happen in an existing pixel-art editor (Aseprite, LibreSprite or Piskel); the app does not edit pixels. Uploaded sheets go to a Supabase storage bucket and their manifests (the `SpriteAtlas` JSON from Plan 1) to a `sprite_atlases` table. At startup the app downloads them (cached for offline like ball images) and calls `SpriteRegistry.register(atlas, sheet, idPrefix: 'custom.<atlasId>')`. Skills gain sprite slots that name a registry id; drawing code asks the skill's slot first and falls back to the built-in art. An admin screen, "Sprites", under Skill Management lists atlases and opens the importer (upload, slice, preview, save).

**Tech Stack:** Flutter (`file_picker` bytes, `dart:ui` decode), Supabase (storage + table + RLS like `ball-images` and `app_settings`), the Plan 1 atlas model and registry.

**Depends on:** `docs/superpowers/plans/2026-10-27-sprite-atlas-system.md` (complete first: `SpriteAtlas`, `SpriteRegistry.register/unregister/frame/ids`, isolation rules).

**Spec / decisions (owner, 2026-10-27):** in the app (not a separate project); admin only; attachable to skill icon / held weapon, projectile, impact / effect, and replacing built-in art. Use existing editors (Aseprite, LibreSprite, Piskel, TexturePacker) for drawing; import their JSON.

## Global Constraints

- Admin only: uploads and atlas writes are gated by `is_admin()` RLS and by the separate admin client (`SupabaseAdminAuth.client`), like settings.
- The app slices, previews, optimizes and attaches owner uploads; the owner requested automatic runtime resizing on 2026-10-28. Original files stay untouched. The AGENTS.md PhotoCraft rule still governs developer raster editing in the repository.
- Source limits: PNG/WebP, 16 MB, 8192 px per side and 16 megapixels. Optimized uploads: at most 4 MB and 4096 x 4096 px; at most 64 sprites and 256 frames per atlas. Icon/held frames max 128 px; projectile/effect frames max 256 px.
- Every screen is 440 px wide on wide screens like Settings (`ColoredBox > Center > ConstrainedBox(maxWidth: 440) > Scaffold`); the slicing view may scroll/zoom inside it.
- Long editors use grouped tabs; fixed LABEL | CONTROL rows; right-aligned numbers; save failures are shown, never silent; UI text has no en or em dashes.
- Rendering only: no change to simulation, RNG draws or match outcomes; sprite choices are cosmetic.
- Offline: atlases and sheets are cached in `OfflineStore` and used when offline.
- Replays: a replay keeps working when a sprite is later deleted or the viewer has never downloaded it; the built-in art is drawn instead.

## Review Focus

- An Aseprite export in "array" vs "hash" JSON form, with trimmed frames (`spriteSourceSize`) or rotated frames: both forms import; trimmed frames keep their position inside the original frame; rotated frames are refused with a clear message.
- A sheet with no JSON and uneven art (like `effects-animated.png`): grid slicing plus "Trim to clean edges" gives isolated frames; frames that cannot be isolated are flagged before Save.
- A skill attached to a sprite that the admin later deletes: matches, replays and the editor show the built-in art and the editor marks the slot "missing".
- A slow or failed download at startup: the app starts on time with built-in art; custom sprites appear once loaded, without a restart.
- A huge or wrong file (8 MB, JPEG with no alpha, 10000 px): rejected before upload with the reason.

---

## File Structure

| File | Responsibility |
|---|---|
| `supabase/migrations/022_sprite_atlases.sql` (new) | `sprite-sheets` bucket (public read, admin write, 4 MB, PNG/WebP) and `sprite_atlases(id uuid, name text, sheet_path text, manifest jsonb, updated_at)` with admin-write RLS. |
| `lib/core/sprites/sprite_import.dart` (new) | Pure: convert Aseprite (hash and array) and TexturePacker JSON into `SpriteAtlas`; grid slicing; trim to clean edges from RGBA bytes. |
| `lib/features/sprites/data/sprite_atlas_repository.dart` (new) | Supabase list/save/delete of atlases and sheets; offline cache. |
| `lib/features/sprites/application/custom_sprite_loader.dart` (new) | Startup: fetch atlases, decode sheets, `SpriteRegistry.register`. |
| `lib/features/sprites/presentation/sprites_screen.dart` (new) | Admin list of atlases (thumbnail, name, sprite count, used-by). |
| `lib/features/sprites/presentation/sprite_import_screen.dart` (new) | Upload, slice (JSON / grid / trim), name sprites, set timing, preview, save. |
| `lib/features/skills/domain/skill_library.dart` | `SkillDefinition` sprite slots. |
| `lib/features/skills/presentation/skill_management_screen.dart` | Slot pickers in Appearance; "Sprites" entry point. |
| `lib/features/arena_simulation/presentation/power_up_painter.dart`, `harpoon_cinematic.dart` | Ask the skill's slot first. |

## Data decisions

- Custom sprite ids: `custom.<atlas uuid>.<sprite name>`; sprite names are `[a-z0-9-]{1,40}`.
- `SkillDefinition` gains `iconSpriteId`, `projectileSpriteId`, `impactSpriteId` (all `String?`, JSON keys `icon_sprite`, `projectile_sprite`, `impact_sprite`). Icon covers the field token and the held weapon. Null: built-in art.
- Replacing built-in art = setting the slot on the built-in skill's override (`builtin.<kind>`), so the existing override/restore-defaults flow covers it.
- Lookup order when drawing: skill slot id (if registered) -> today's built-in id -> vector glyph.

---

### Task 1: Import formats and slicing (pure)

**Files:**
- Create: `lib/core/sprites/sprite_import.dart`
- Test: `test/core/sprites/sprite_import_test.dart` (fixtures: small Aseprite hash JSON, array JSON, TexturePacker JSON, trimmed frame, rotated frame, written inline)

**Interfaces:**
- Consumes: `SpriteAtlas`, `SpriteDef`, `SpriteFit` (Plan 1).
- Produces:
  - `SpriteAtlas importAseprite(Map json, {required String sheet})`: frame tags become sprites (tag name -> sprite name, `from..to` frames, average `duration` ms -> `stepsPerFrame = round(ms * 60 / 1000)`); without tags, one sprite named after the file holding every frame.
  - `SpriteAtlas importTexturePacker(Map json, {required String sheet})`: frames grouped by name prefix before a trailing number (`flame_0`, `flame_1` -> `flame`).
  - `SpriteAtlas sliceGrid({required String sheet, required int columns, required int rows, required int cellWidth, required int cellHeight, int inset = 0, required Map<int, String> rowNames})`.
  - `List<Rect> trimToCleanEdges(Uint8List rgba, int sheetWidth, List<Rect> frames, {int alphaThreshold = 24, int search = 40})`: same rule as Plan 1's `make_atlas.py`.
  - Each importer throws `FormatException` with a plain message for rotated frames or missing fields.

- [ ] **Step 1: Write failing tests**: `aseprite hash with two tags gives two sprites with their frame rects and timing`; `aseprite array gives the same atlas as hash`; `trimmed aseprite frame keeps its offset inside the source frame`; `rotated frame is refused`; `texturepacker groups flame_0..3 into flame`; `grid slicing names rows`; `trimToCleanEdges moves an edge off art that leaks from the neighbor cell` (synthetic RGBA).
- [ ] **Step 2: Run** `flutter test test/core/sprites/sprite_import_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `sprite_import.dart`.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sprites): import Aseprite/TexturePacker JSON, grid slicing, clean-edge trim`.

### Task 2: Storage, table and repository

**Files:**
- Create: `supabase/migrations/022_sprite_atlases.sql`, `lib/features/sprites/data/sprite_atlas_repository.dart`
- Test: `test/features/sprites/sprite_atlas_repository_test.dart` (fake repository + JSON round trip); `test/supabase/migrations_test.dart` keeps passing.

**Interfaces:**
- Produces:
  - `class CustomAtlas { final String id; final String name; final String sheetUrl; final SpriteAtlas atlas; final DateTime updatedAt; }`
  - `abstract class SpriteAtlasRepository { Future<List<CustomAtlas>> list(); Future<CustomAtlas> save({String? id, required String name, required Uint8List sheet, required String contentType, required SpriteAtlas atlas}); Future<void> delete(String id); }`
  - `SupabaseSpriteAtlasRepository(SupabaseClient reader, {SupabaseClient? writer})`: reads with the app client, writes with the admin client; `list()` caches the last good list in `OfflineStore` (`sprites:atlases`) and falls back to it offline, with `.retry(enabled: false)` like other startup queries; sheet bytes are cached by URL like ball images.
- Migration: bucket `sprite-sheets` (public read, admin write, 4 MB, `image/png`, `image/webp`); table `sprite_atlases` with `manifest` checked as a JSON object no larger than 256 KB; RLS: select for all, insert/update/delete for `is_admin()`.

- [ ] **Step 1: Write failing tests**: a `CustomAtlas` JSON round trip; `save` rejects a sheet over 4 MB or over 4096 px before any upload (fake client records no calls); `list` returns the cached list when the reader throws.
- [ ] **Step 2: Run** `flutter test test/features/sprites/`. Expected: FAIL.
- [ ] **Step 3: Write the migration and implement the repository.**
- [ ] **Step 4: Run** `flutter test test/features/sprites/ test/supabase/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sprites): sprite atlas storage, table and repository (migration 022)`.

### Task 3: Load custom sprites at startup

**Files:**
- Create: `lib/features/sprites/application/custom_sprite_loader.dart`
- Modify: `lib/app.dart` (start loading after settings, like `OfflineSync`; never block the first screen), `lib/core/offline/offline_sync.dart` (include sprite sheets)
- Test: `test/features/sprites/custom_sprite_loader_test.dart`

**Interfaces:**
- Consumes: `SpriteAtlasRepository` (Task 2), `SpriteRegistry.register/unregister` (Plan 1).
- Produces: `class CustomSpriteLoader { CustomSpriteLoader(SpriteAtlasRepository repo, {Future<Uint8List> Function(Uri)? fetch}); Future<void> load(); final ValueNotifier<int> revision; }` registers each atlas as `custom.<id>`, skips (and logs) one that fails to decode, bumps `revision` so painters repaint once sprites arrive.

- [ ] **Step 1: Write failing tests**: two atlases register under `custom.<id>.<name>`; one corrupt sheet is skipped and the other still registers; a repository error leaves built-in sprites working and `load()` completes.
- [ ] **Step 2: Run** `flutter test test/features/sprites/custom_sprite_loader_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the loader and wire it in `app.dart` and `OfflineSync`.
- [ ] **Step 4: Run** the same command, then `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sprites): load uploaded sprites at startup and for offline play`.

### Task 4: Skill sprite slots and drawing

**Files:**
- Modify: `lib/features/skills/domain/skill_library.dart`, `power_up_painter.dart`, `harpoon_cinematic.dart`, `arena_effect_library.dart`
- Test: `test/features/skills/skill_sprite_slots_test.dart`, `test/features/arena_simulation/presentation/power_up_painter_test.dart`

**Interfaces:**
- Consumes: `SpriteRegistry.frame/has` (Plan 1).
- Produces: `SkillDefinition.iconSpriteId`, `projectileSpriteId`, `impactSpriteId` (JSON `icon_sprite`, `projectile_sprite`, `impact_sprite`; `copyWith` clears with null like `payloadSkillId`); helper `ui.Image? skillSprite(String? slotId, String builtInId, int frame)` in `power_up_painter.dart` implementing the lookup order.

- [ ] **Step 1: Write failing tests**: slots round-trip through JSON, `copyWith`, library save/restore and the replay snapshot; with a registered `custom.a.flame`, a skill whose `impactSpriteId` is `custom.a.flame` draws that frame (paint into a recorder and compare against the registered image's pixels); an unregistered slot id draws the built-in art; built-in override with `iconSpriteId` changes the pistol's token and held weapon; Restore defaults clears it.
- [ ] **Step 2: Run** the two test files. Expected: FAIL.
- [ ] **Step 3: Implement** the fields and the lookup in the painter, cinematic and effect library.
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sprites): skills can use uploaded sprites for icon, projectile and impact`.

### Task 5: Sprites screen and importer

**Files:**
- Create: `lib/features/sprites/presentation/sprites_screen.dart`, `sprite_import_screen.dart`
- Modify: `skill_management_screen.dart` (a "Sprites" button for the admin; slot pickers in the skill editor's Appearance tab with thumbnails and a "Built-in art" option; missing slots shown in red)
- Test: `test/features/sprites/sprite_import_screen_test.dart`, additions to `test/features/skills/skill_management_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 4.
- Produces: `SpritesScreen({required SpriteAtlasRepository repository})` (list: thumbnail, name, sprite count, skills using it; delete asks first and names the skills that fall back to built-in art); `SpriteImportScreen({required SpriteAtlasRepository repository, CustomAtlas? existing})` with tabs **Sheet** (pick PNG/WebP and optional JSON; size and alpha checks), **Slices** (JSON result or grid fields; "Trim to clean edges"; frames drawn as boxes, unclean ones red), **Sprites** (name, frame order, speed in frames per second shown as text, anchor, fit), **Preview** (animation over the arena background at real size, with tint; Sprite/Vector toggle respected), and Save (disabled with the reason while problems remain; failures shown with a retry).

- [ ] **Step 1: Write failing widget tests**: importing a fixture Aseprite JSON lists its tags as sprites; a grid slice with a leaking frame shows it red and disables Save with the reason; Save calls `repository.save` with the expected `SpriteAtlas`; a save failure shows the error and keeps the edits; the screen is 440 px wide on a 1600 px window; in the skill editor, choosing an uploaded sprite for Impact saves `impactSpriteId`.
- [ ] **Step 2: Run** the test files. Expected: FAIL.
- [ ] **Step 3: Implement** the two screens and the pickers.
- [ ] **Step 4: Run** `flutter analyze` and `flutter test`. Expected: no issues, all pass.
- [ ] **Step 5: Commit** `feat(sprites): Sprites screen and importer for the admin`.

### Task 6: Docs and end-to-end check

**Files:**
- Modify: `docs/SPRITES.md` (from Plan 1), `CLAUDE.md`, `README.md` (migration list)

- [ ] **Step 1: Write the owner's guide in `docs/SPRITES.md`**: drawing in Aseprite / LibreSprite / Piskel (transparent background, 2 px clear border between frames, export "Sprite sheet + JSON data", array or hash), importing, attaching to a skill, replacing built-in art, deleting.
- [ ] **Step 2: Update `CLAUDE.md`** (sprites feature, migration 022, slot lookup order) and README's migration range.
- [ ] **Step 3: End-to-end on web and an Android phone** (`flutter run --profile -d <device>`): import a small Aseprite animation, attach it as a skill's impact, play a match, save a replay, open the replay on another device, turn the network off and reopen. Record the result in the commit message.
- [ ] **Step 4: Run** `flutter analyze` and `flutter test`. Expected: no issues, all pass.
- [ ] **Step 5: Commit** `docs(sprites): owner guide; migration 022 in docs`.
