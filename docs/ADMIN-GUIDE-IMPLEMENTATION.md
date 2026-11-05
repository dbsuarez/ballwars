# Admin Guide implementation

Date: 2026-11-05. This is a read-only help feature; no database migration is needed.

## Access and organization

Admin Settings > General > Admin Guide opens the catalog. Skill editor section info and individual field info offer Read full guide. Numeric fields select the relevant topic and explanation; a generic unknown field opens guide search. Existing editor controls and save behavior remain unchanged.

Tutorials provide a numbered walkthrough with a native Flutter stage diagram. How it works explains identity/mechanics/presentation, mechanical steps versus visual events, testing/saving and compatibility limits. Parameters groups related controls, with examples, units and relevant preview guidance. Search spans all tabs temporarily; clear returns to the selected tab. The last tab is remembered.

## Content maintenance

`assets/help/admin_guide.json` is the source of truth. The catalog validates topic IDs and related links when loaded; loading problems have a visible retry state. `python tools/export_admin_guide.py` creates `docs/ADMIN-GUIDE.md`; `--check` verifies synchronization. Update the catalog whenever the corresponding runtime/editor behavior changes.

The guide currently documents 20 topics and 116 explanation/step sections. It uses existing Flutter icons and code-native layout, with no generated image assets or external network dependency.

## Flamethrower question

The guide release did not change runtime geometry. The subsequent shared-emitter implementation now reuses saved launch offsets for projectile emission, flamethrower visuals/cone hits, Energy Wave charge/sweep/hit bearing and custom beam hit rays. See [shared emitter notes](SHARED-ATTACK-EMITTER.md).

## Verification

- 61 focused guide/settings/editor safety tests passed (`build/admin-guide-final-tests.log`).
- Static analysis clean (`build/admin-guide-final-analysis.log`).
- Release web build passed (`build/admin-guide-web-build.log`); bundled guide JSON matches the source SHA-256.
- Narrow-phone (320 px) and desktop (1100 px) runtime renders inspected with the actual theme/fonts (`build/admin-guide-visual.log`, ignored build captures).
- Generated Markdown synchronization check passed (`python tools/export_admin_guide.py --check`).

Coverage includes cross-tab search and clear, back navigation, contextual parameter focus, admin-only Settings entry and preservation of unsaved editor values with no save callback invocation. Existing editor/settings regressions ran alongside these cases. No database migration, deployment, release or phone installation is part of this guide delivery.

## Release submission

The user subsequently requested deployment and release on 2026-11-05. The guide is included in the v1.14.54 master/tag submission. GitHub workflows publish the web build and signed APK; their completion is left for manual checking.
