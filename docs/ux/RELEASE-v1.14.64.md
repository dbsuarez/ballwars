# Ball Wars v1.14.64

Deployment/release submission: 2026-11-07. Push master for the web deployment
workflow and annotated tag v1.14.64 for the signed Android APK workflow.
Workflow completion is checked manually by the user.

## Changes

- Settings > Appearance > UI Skin: Classic Arcade (default) and Battle Garage.
- Per-device persistence, actual screen previews and visible save/retry errors.
- Battle Garage ticket panels, raised button artwork, workshop background and
  bundled Inter font with SIL OFL notice. Existing layouts and gameplay retained.
- Editable FigCraft design package and Flutter implementation documentation.

## Validation

34 focused checks passed, plus a final nine-check skin/screenshot run. Analysis
has no issues and the release web build passed. Seven runtime screenshots and
details are in [the skin report](skins/README.md).

The attempted serial full suite stopped after 756 passing checks because Windows
exhausted memory. Its earlier font-license expectation failure was corrected and
the focused license checks passed. A complete full-suite pass is not claimed.

Publishing master and the tag triggers workflows; it does not establish that the
APK has finished building or production has passed device acceptance. No workflow
monitoring or phone installation is performed. The release workflow derives
Android versionCode 1014064 from the tag.
