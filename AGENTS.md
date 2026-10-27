# Ball Wars image workflow

## Settings UX

- Group long settings editors into clearly named tabs instead of one long list. Keep related controls together and preserve unsaved edits when switching tabs. For Skill Management use Identity (including behavior), Damage & Timing, Appearance, and Callouts & Sounds.

- Use the installed PhotoCraft CLI for all raster image editing and sprite processing: `C:\Program Files\PhotoCraft\photocraft-cli.exe`.
- Read `docs/PHOTOCRAFT-CLI-HANDOFF.md` before processing image assets. Use the tested helpers in `tools/photocraft/` to avoid Windows PowerShell JSON quoting errors.
- When new illustrated artwork is needed, provide the user with a precise generation prompt. The user will generate it with another AI and supply the result. Do not invoke AI image generation/editing unless the user explicitly changes this policy.
- PhotoCraft can also create simple local artwork with shapes, text, layers and filters. It is not verified as an AI text-to-image generator.
- Preserve supplied originals. Write edited/normalized assets to new filenames, preserve alpha, inspect the output, and validate sprite dimensions/frame isolation before integration.
- Read-only image inspection and application/runtime rendering are allowed; perform raster modifications through PhotoCraft rather than another image editor.

## Vector and audio asset workflow

- Use the installed VectorCraft CLI for local vector artwork (icons, callout shapes, arena decorations): `C:\Program Files\VectorCraft\vectorcraft-cli.exe`. Read `D:\Development\artcraft-usage\vectorcraft\NOTES.md` first; search its `REFERENCE.md` only for needed commands. Preserve editable SVG/native masters and export a PNG for visual inspection. Check SVG compatibility with Flutter before integration; raster editing remains PhotoCraft's job.
- Use the installed SoundCraft CLI for local sound design and audio editing: `C:\Program Files\SoundCraft\soundcraft-cli.exe`. Read `D:\Development\artcraft-usage\soundcraft\NOTES.md` first; search its reference for additional commands. Use script files to avoid Windows JSON quoting issues. Preserve source audio/session files and export new filenames; validate duration, clipping, and playback before integration.
- SoundCraft's documented output formats are WAV, AIFF, and FLAC, not MP3. Prefer WAV for initial game integration and verify both browser and Android playback. Local tone generation does not imply speech or music generation support.
- Reuse the ArtCraft examples as command wrappers. Do not invoke AI image generation for these workflows. Tool availability does not authorize replacing existing game artwork or audio without a task requiring it.
