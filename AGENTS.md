# Ball Wars image workflow

- Use the installed PhotoCraft CLI for all raster image editing and sprite processing: `C:\Program Files\PhotoCraft\photocraft-cli.exe`.
- Read `docs/PHOTOCRAFT-CLI-HANDOFF.md` before processing image assets. Use the tested helpers in `tools/photocraft/` to avoid Windows PowerShell JSON quoting errors.
- When new illustrated artwork is needed, provide the user with a precise generation prompt. The user will generate it with another AI and supply the result. Do not invoke AI image generation/editing unless the user explicitly changes this policy.
- PhotoCraft can also create simple local artwork with shapes, text, layers and filters. It is not verified as an AI text-to-image generator.
- Preserve supplied originals. Write edited/normalized assets to new filenames, preserve alpha, inspect the output, and validate sprite dimensions/frame isolation before integration.
- Read-only image inspection and application/runtime rendering are allowed; perform raster modifications through PhotoCraft rather than another image editor.
