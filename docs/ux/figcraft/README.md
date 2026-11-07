# Ball Wars — The Battle Garage

Editable screen concept, created in **FigCraft 0.16.0 on 2026-11-07**.

Open **[Ball-Wars-Arcade-Concept.figcraft](Ball-Wars-Arcade-Concept.figcraft)**.
The document embeds its images. It has **10 boards, 12 editable color variables,
and seven text-free component masters**. Home is selected when the file opens.

This is a design package and a Flutter feasibility proof. The concept has not
replaced the shipped app; these static mockups are not connected game screens.

## Screens

| Board | Preview | Purpose |
| --- | --- | --- |
| 01 Home | [Phone](previews/01-home.png) | Supplied hero, large primary action, all five modes, groups and replays |
| 02 Match Setup | [Phone](previews/02-match-setup.png) | Lineup, settings groups, arena and pickup presets |
| 03 Live Battle | [Phone](previews/03-live-battle.png) | Full-width arena, six-ball standings and spectating controls |
| 04 Winner | [Phone](previews/04-winner.png) | Centered panel, winning move, tally and replay/save actions |
| 05 Skill Library | [Phone](previews/05-skill-library.png) | Unified category/search/filter workflow and rarity frames |
| 06 Skill Editor | [Phone](previews/06-skill-editor.png) | Six sections, aligned artwork previews and persistent testing toolbar |
| 07 Power-up Test | [Phone](previews/07-power-up-test.png) | Full-width arena, collapsible rails and central 72 px Play |
| 08 Battle | [Landscape](previews/08-battle-landscape.png) | 800×360 viewport and existing centered 440 px app window |
| 09 Home | [Narrow phone](previews/09-home-narrow-phone.png) | 360×800 variant |
| 10 Component kit | [Board](previews/10-component-kit.png) | Palette, skin masters, spacing and controls |

[Whole-document overview](previews/overview.png) ·
[Actual Flutter rendering](previews/flutter-proof-390x844.png) ·
[Implementation handoff](FLUTTER-HANDOFF.md)

## Flutter feasibility

Every visual is text, an image, a simple path, a circle, a line, opacity or a flat
fill. No unavailable design-tool effects, proprietary animation players or custom
shaders are required. Use the PNG skins with `Image.centerSlice`, or draw them with
`CustomPainter`/`ClipPath`. Labels and input remain separate Flutter widgets.

The proof in `test/visual/verify_figcraft_design.dart` loads the actual exported
skins and sprites, checks transparent corners, resizes them at 320, 390 and 800 px
viewports, and exercises touch and keyboard activation. It demonstrates the custom
controls; it does not implement all screen flows or establish pixel identity
between FigCraft and Flutter.

## Files and reproduction

- `Ball-Wars-Arcade-Concept.figcraft`: editable source with embedded images.
- `build_design.py`: design construction and export script.
- `skins/`: three button states and four rarity card skins, PNG and SVG.
- `assets/`: existing project sprites isolated through PhotoCraft.
- `fonts/`: Inter variable font and its original OFL notice.
- `ARTWORK.json`: source hashes and PhotoCraft processing provenance.
- `DESIGN-MANIFEST.json`: export dimensions, center slices and hashes.
- `VALIDATION.json`: actual checks and their boundaries.

From the project root:

```powershell
python docs/ux/figcraft/build_design.py
flutter test test/visual/verify_figcraft_design.dart
```

The builder uses `C:\Program Files\FigCraft\figcraft-cli.exe`, overridable through
`FIGCRAFT_CLI`. Its command script goes under ignored `build/figcraft-design`.
The normalized PNG inputs are included; rebuilding needs no further image editing.

## Rights and scope

The hero is the previously approved user-supplied illustration. Originals and
runtime art are unchanged. Sprites come from existing project atlases. New
geometric UI artwork was constructed locally in FigCraft. No paid kit, third-party
illustration or AI image generation was used.

Inter comes from the [official Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/inter);
its [OFL notice](fonts/OFL.txt) remains with the font. FigCraft's installed NOTICE
declares MIT OR Apache-2.0; no ArtCraft branding is copied.

These assets remain under `docs`. No production asset bundle, app route, gameplay,
database, deployment or APK release is changed by this task.
