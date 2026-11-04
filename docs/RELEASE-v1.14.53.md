# Ball Wars v1.14.53

Batch 4 replay and video export delivery, 2026-11-05.

- Keep Classic video and add Watching view with independent visibility choices for names, pictures, health, standings, equipped items, callouts, arena text, watermark and closing scenes.
- Keep separate BGM/SFX choices without changing live match preferences.
- Add portable .bw import/export to Saved Replays and explain failed replay links with retry for connection failures.
- Preserve changing-arena settings and custom-only/empty pickup selections in replay and export.
- Introduce simulation revision 7 for stable targeting, preserving documented legacy targeting for historical revisions.
- Add a separate admin video-watermark setting, default cha0s' Balls.

Apply supabase/migrations/028_export_watermark.sql to customize the saved video watermark. Until then, the default works and customization reports the missing migration explicitly.

Validation: full suite 1,659 passed, one skipped; additional post-rotation exported-frame parity fixture passed separately. Analysis clean. Release web and signed APK builds passed before the version-only release bump. Device/manual acceptance is listed in docs/BATCH4-REPLAY-EXPORT.md.

Master push triggers Pages deployment; v1.14.53 triggers signed APK release publication. Workflow completion is not monitored.
