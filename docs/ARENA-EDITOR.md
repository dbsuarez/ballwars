# Arena editor

Implemented locally on 2026-11-05. Open **Admin Settings > Appearance > Manage arenas**.

## Create and use a map

Duplicate a template or create an arena. The editor has Identity, Appearance and Geometry tabs, with a live preview and a fixed Save/Test toolbar. Switching tabs preserves edits. Configure its name, player availability, background template, floor/detail/boundary colors, circle or square boundary, and optional center obstacle. Arena trap sets are independent of the background; their default enabled state is configurable.

Test opens Power-up Test with the unsaved map. Save publishes the catalog through the existing administrator settings permissions. Failed saves remain visible and preserve the draft. This editor composes existing arena templates and one center obstacle; it does not provide freehand wall placement or background uploads.

The shared regular selection dialog exposes available maps to players and administrators. Match Setup remembers selections and geometry overrides separately per game mode. Hidden/deleted selections require choosing another map before starting. Catalog defaults apply unless a player chooses otherwise.

## Rendering and replay

All background templates fill square bounds, then the active arena shape clips them. The default grid also fills square corners. Neon laser endpoints follow the actual circle/square boundary and shrinking radius; diagonal square gates reach the corners. Other rim traps already use boundary-aware geometry.

Custom-map matches record a complete immutable map snapshot in replay revision 9, including colors, trap set and geometry. Saved replay documents and exported video retain that snapshot after a map is edited or deleted. Older clients reject revision 9 rather than silently dropping the map. Ordinary matches retain revision 8. Center obstacle size round-trips without rounding away collision geometry.

## Production requirement

Apply `supabase/migrations/029_arena_catalog.sql`, then reload the app before saving shared custom maps. It adds a bounded JSON catalog to app_settings under existing administrator write policies. Missing migration or a discarded server write produces an explicit save error.

## Verification

- [x] Full Flutter suite: 1,700 passed, one skipped.
- [x] Release web build.
- [x] Targeted domain, persistence, editor, per-mode settings, replay/video and boundary pixel regressions.
- [x] Phone-width (320px) and desktop-width editor rendering reviewed.
- [ ] Apply migration 029 in production.
- [ ] Verify published map save/load and selection on an actual phone and a second signed-in device.
- [ ] Deploy when requested. No APK release is included in this change.
