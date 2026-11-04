# Ball Wars v1.14.54

Admin Guide delivery, 2026-11-05.

- Admin Settings > General > Admin Guide: 20 searchable offline topics, grouped into Tutorials, How it works and Parameters.
- Numbered skill/sprite walkthroughs and a native Flutter stage diagram.
- Contextual section/field links from the skill editor, preserving unsaved drafts.
- Grouped explanations of mechanics, units, visual roles, placement, timing, sound and saving.
- A Markdown reference generated from the same bundled catalog.

The guide documents the existing native flamethrower origin limitation; this release does not change its cone/emitter behavior. No new database migration is needed for this guide feature.

Validation: 61 focused guide/settings/editor regressions passed, static analysis clean, release web build passed, phone/desktop runtime layouts inspected and bundled catalog hash verified. GitHub release workflow runs the full suite and builds the signed APK as 1.14.54 / 1014054.

Master/tag pushes trigger Pages deployment and APK release publication. Workflow completion is not monitored.
