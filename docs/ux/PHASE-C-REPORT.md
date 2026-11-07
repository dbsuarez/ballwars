# Phase C: Skill workbenches

Implemented on 2026-11-07. Not deployed or released in this pass.

## Changes

- Skill Library uses rarity-framed, beveled cards with existing sprites, descriptions and menus. Category, Source, Status and Rarity filters now have visible labels. The unified library and Global Defaults remain together.
- The six-section Skill Editor keeps Identity, Mechanics, Timing & Delivery, Visuals & Sprites, Audio & Callouts and Test & Preview. Section headings use shared game chrome. Save is prominent; the existing enabled/disabled validation, failure recovery and unsaved drafts remain.
- Ball Studio and Skill Demo share the arcade palette, typography, panels and native controls. Studio Save, preview, presets and demo activation/audio/speed controls retain their behavior.
- Library and Studio scroll on short windows while retaining their tab state. The existing arena renderers and simulation are untouched.
- Supporting library/editor/Studio dialogs use the same scoped theme. Configured non-default palettes and contrasting icon-button roles are retained. Helper/error messages can wrap to three lines.

## Verification

Affected regressions: **141 passed**, including explicit responsive runtime captures. Static analysis: **no issues found**. Production-path release web build: **passed, exit 0**. [Commands and log hashes](PHASE-C-VALIDATION.json). Screenshots use actual Flutter widgets with bundled fonts and sprite assets, without a signed-in account or production writes.

Reproduce with pinned Flutter 3.38.5:

```powershell
flutter test test/visual/capture_skill_ui.dart
```

Runtime captures cover Library, Editor, Ball Studio and Skill Demo at 360x800, 800x360 and 440x900. Short-landscape capture explicitly scrolls to a skill before opening it. Older editor tests now scroll to filtered entries rather than attempting off-screen taps; their save, rarity and compatibility assertions remain intact.

## Screenshots

| Screen | Phone | Short landscape | Larger frame |
| --- | --- | --- | --- |
| Skill Library | [360x800](screenshots/phase-c/library-360x800.png) | [800x360](screenshots/phase-c/library-800x360.png) | [440x900](screenshots/phase-c/library-440x900.png) |
| Skill Editor | [360x800](screenshots/phase-c/editor-360x800.png) | [800x360](screenshots/phase-c/editor-800x360.png) | [440x900](screenshots/phase-c/editor-440x900.png) |
| Ball Studio | [360x800](screenshots/phase-c/studio-360x800.png) | [800x360](screenshots/phase-c/studio-800x360.png) | [440x900](screenshots/phase-c/studio-440x900.png) |
| Skill Demo | [360x800](screenshots/phase-c/demo-360x800.png) | [800x360](screenshots/phase-c/demo-800x360.png) | [440x900](screenshots/phase-c/demo-440x900.png) |

[Capture dimensions and hashes](PHASE-C-SCREENSHOTS.json).

## Boundaries

No gameplay, hit detection, replay schema, skill IDs, tuning defaults, persistence format, dependency, version, signing or workflow changes. No new illustrated artwork, image generation, external assets or cumulative ZIP. Actual phone/browser acceptance remains manual. Phase D is the next visual slice.
