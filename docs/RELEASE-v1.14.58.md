# Ball Wars v1.14.58

- Fix My Groups ball creation: group-local ordering indices replace overflowing millisecond timestamps. Existing deterministic ordering is preserved; permission and range failures remain visible.
- Edit Arena has a dedicated Media Library tab, with all four tabs visible on phone screens.
- Adjust existing background crop/position without reuploading or modifying the shared image. Uploads and saved-image previews support finger pan and pinch zoom; sliders remain available.
- Dim backgrounds independently of balls, text, walls, traps and effects. Adjustments persist in map settings, preview, replay and video.
- Updated Help and roadmaps. Adjusted backgrounds use map definition version 3; update web/APK clients before editing these maps.

Validation: 49 group/persistence tests and 142 arena/setup/replay/export tests passed; lint clean; release web builds passed; 320px editor views inspected. Actual phone/browser acceptance remains manual.

No additional database migration is required. Master push triggers Pages deployment; tag v1.14.58 triggers the signed APK workflow and GitHub Release. Workflow completion is left to the user.
