# Ball Wars v1.14.56

- Named arena editor under Admin Settings > Appearance > Manage arenas, with tabbed controls, draft testing, shared selection, colors, geometry and independent trap sets.
- Full square background coverage, clipped by the selected arena boundary. Square lasers reach boundary corners and follow arena shrinkage.
- Custom map snapshots persist in replay documents and exported video; revision 9 prevents older clients silently dropping maps.
- Generated build/worktree files excluded from lint analysis. Flame feasibility documented; current renderer retained.

Migration 029 was applied by the user on 2026-11-05.

Validation: 1,700 tests passed, one skipped; whole-project analysis clean; release web build passed; 320px and desktop editor visual checks passed. Production/device acceptance remains manual.

Master push triggers Pages deployment. Tag v1.14.56 triggers the signed APK workflow and GitHub Release. Workflow completion is not monitored automatically.
