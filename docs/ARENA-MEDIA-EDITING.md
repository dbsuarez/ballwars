# Arena media editing

Open **Admin Settings > Appearance > Manage arenas > Edit > Media Library**.

All four editor tabs remain visible on small screens. Appearance keeps template/colors, Geometry keeps collision/traps, and Media Library owns images. Draft changes survive switching tabs.

## Adjust an existing image

The selected image is immediately editable. Pinch with two fingers to zoom (1-4x), then drag with one finger to reposition it. Sliders provide the same adjustments. At 1x, an already-square saved image is fully visible and has no spare area to pan; zoom in first. Scroll outside the image to reach more controls.

**Dim image** ranges from 0% (original) to 100% (black). It darkens only the background image; balls, center walls, text, traps and effects keep their colors. The arena preview updates immediately. Reset image adjustments restores the saved image's full framing and brightness.

These edits only change this map's settings. They do not upload pixels, replace the library asset, or change other arenas using it. Previously cropped-away regions are not stored in the normalized upload; recovering them requires choosing the original file again.

## Upload or choose media

Upload & crop uses the same finger gestures and retains the existing crop sliders and pre-upload size controls. The original file remains untouched; only the cropped/normalized image is uploaded. Library selects an existing arena image. Use template clears the image assignment. Choosing another image resets map-local image adjustments.

Save commits the map and all image adjustments. Failed saves retain the draft and show an error for retry. Test uses the current unsaved appearance.

## Compatibility and verification

No database migration is required. Image adjustments are encoded in definition version 3; older apps reject this definition instead of silently deleting the settings. Older template/image definitions still load with their original brightness/framing. Update browser/APK clients before editing adjusted maps.

The shared renderer uses the same source-pixel crop as the touch preview, including replay/video snapshots. Tests exercise touch pan and pinch inside a scrolling page, persisted drafts, failure/retry/reopen without an uploader, schema validation/replay round-trip, image pixel colors, unchanged shared artwork and foreground wall brightness. Manual phone/browser acceptance remains separate.

Validation: 142 focused arena, match-setup, replay and video-export tests passed; lint clean. The 320px media tab and dim controls were rendered and inspected. Release web build passed.

Deployment and signed APK release submitted as v1.14.58 on 2026-11-05. Workflow completion remains a manual check.
