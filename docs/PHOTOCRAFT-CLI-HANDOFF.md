# PhotoCraft CLI handoff for another AI

Verified locally on **2026-10-27**, Windows PowerShell **5.1**.
Installed version: **photocraft-cli 0.16.0 (b1794c6e0, 2026-10-25)**.

## User's standing instruction

Use **PhotoCraft for all raster image editing and sprite processing**. If new illustrated artwork is required, give the user a precise prompt; the user generates it elsewhere and supplies the image. Do not use an AI image-generation/editing service unless the user explicitly changes this instruction.

Ordinary PhotoCraft operations below run locally. They do not call OpenAI image generation. An AI agent's reasoning, tool usage and image inspection still have their normal account usage costs. No claim is made about PhotoCraft licensing or untested features.

PhotoCraft can create simple artwork locally with shapes, text, gradients, layers and filters. No AI text-to-image command was found in this installed command registry.

**Pass this document and the `tools/photocraft` folder to the next AI.** Installation paths and project roots can be changed in the examples.

## Executables and first checks

```powershell
$pc = 'C:\Program Files\PhotoCraft\photocraft-cli.exe'
& $pc --version
& $pc --help
& $pc run --help
& $pc commands --help
```

`photocraft-cli.exe` is the headless CLI. `photocraft.exe` is the desktop app; ordinary image processing does not need a GUI window.

Top-level commands:

| Command | Purpose |
| --- | --- |
| `info FILE [--compact]` | JSON document metadata: dimensions, mode, depth, layers, warnings. |
| `convert IN OUT` | Convert/export by output extension. |
| `run FILE ...` | Open an image, execute ordered engine commands, optionally export. |
| `run --new JSON ...` | Create a document before running commands/exporting. |
| `commands --json --filter TEXT` | Discover actual command IDs and parameter documentation. |
| `batch --actions FILE --in DIR --out DIR` | Apply recorded JSON actions, a droplet or supported Photoshop actions to a folder. |
| `droplet FILE.pcdroplet FILE-OR-DIR...` | Execute a saved droplet. |
| `serve` | Persistent headless JSON-line session. |
| `mcp` | MCP server for an AI client, headless or bridged to the desktop. |

There are **940 engine commands** in this installed version. Discover them rather than guessing names or assuming that a different version has the same registry.

## Windows PowerShell quoting: use the wrapper

Windows PowerShell 5.1 strips JSON double quotes when passing ordinary native arguments. This failed in a real test:

```powershell
# Do not use this form in Windows PowerShell 5.1:
& $pc run $source --cmd image.crop --params '{"x":0,"y":0,"width":444,"height":444}' --out $out
# PhotoCraft received {x:0,y:0,...} and returned exit code 2.
```

Use [Invoke-PhotoCraft.ps1](../tools/photocraft/Invoke-PhotoCraft.ps1). It applies Windows native argument quoting through `ProcessStartInfo`, keeps JSON/path values as data, drains stdout/stderr concurrently, and returns PhotoCraft's exit code. It works with paths containing spaces and square brackets.

```powershell
$root = 'D:\Development\ballwars'
$invoke = Join-Path $root 'tools\photocraft\Invoke-PhotoCraft.ps1'
$source = Join-Path $root 'assets\sprites\Eight-Frame Pixel Lightning Strike.png'
$work = Join-Path $root ('build\photocraft-demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$infoText = & $invoke -CliArgs @('info', '--compact', $source)
if ($LASTEXITCODE -ne 0) { throw 'PhotoCraft inspection failed' }
$info = $infoText | ConvertFrom-Json
$info | Select-Object width,height,mode,depth,layers,warnings
```

Use `ConvertTo-Json -Compress` to create parameter strings. **JSON encoding alone is not shell escaping**; the wrapper handles native quoting separately. Do not build shell expressions from filenames or image metadata. Do not use `Invoke-Expression`.

`run` prints one JSON result per command. Capture it as text and split into lines if processing multiple results. Some successful exports also emit warnings on stderr. Check both warnings and `$LASTEXITCODE`.

## Discover engine commands and parameter schemas

```powershell
& $pc commands --json --filter crop
& $pc commands --json --filter imageSize
& $pc commands --json --filter canvasSize

$commands = (& $pc commands --json) | ConvertFrom-Json
$commands | Where-Object { $_.id -eq 'image.crop' } |
    Select-Object id,label,params,enabled,disabledReason
```

`commands --filter resize` returned no entries. The resize command is **`image.imageSize`**.

Registry entries often say `enabled:false` and `disabledReason:"no document open"`. That is normal during discovery. `run FILE` opens the document before executing its commands.

Useful verified or registry-documented IDs:

| ID | Main parameters |
| --- | --- |
| `image.crop` | `x`, `y`, `width`, `height`; optional `angle`, `deleteCroppedPixels`, `targetWidth`, `targetHeight`, `resample`. |
| `image.imageSize` | `width`, `height`, `resample`; also `percent`, resolution-related settings. |
| `image.canvasSize` | `width`, `height`, `anchor`, `extensionColor`. |
| `image.trim` | `basedOn:"transparent"`, optional `top`, `bottom`, `left`, `right`. |
| `layer.translate` | `dx`, `dy`, optional `layer` and `target`. |
| `file.placeEmbedded` | `path`, `center:[x,y]`, `scale`, `fit`, `smartObject`. |
| `image.adjustments.hueSaturation` | `hue`, `saturation`, `lightness`, `colorize`. |
| `shape.create` | `kind`, `rect:[x,y,width,height]`, `fill`, `stroke`; supports ellipse, rectangle, star, polygon and paths. |
| `type.create` | `x`, `y`, `text`, `size`, `color`, optional `font`, `box`, `align`. |
| `filter.blur.gaussianBlur` | `radius`. |

Crop/resize/pad/trim/place were executed in this verification. Adjustment, shape, text and blur schemas above were inspected in the installed registry; inspect their current schema before using additional options.

## Tested recipes

### Crop and resize an isolated frame

```powershell
$crop = @{ x=0; y=0; width=444; height=444 } | ConvertTo-Json -Compress
$resize = @{ width=128; height=128; resample='nearest' } | ConvertTo-Json -Compress
& $invoke -CliArgs @(
    'run', $source,
    '--cmd', 'image.crop', '--params', $crop,
    '--cmd', 'image.imageSize', '--params', $resize,
    '--out', (Join-Path $work 'frame-00.png')
)
if ($LASTEXITCODE -ne 0) { throw 'Frame processing failed' }
```

Each `--params` belongs to the preceding `--cmd`. Repeated commands execute in order. Use nearest-neighbor resampling for pixel art. For photographs/smooth artwork, choose an appropriate documented interpolator; do not resample sprite sheets across cell boundaries.

### Add transparent padding without scaling pixels

```powershell
$pad = @{ width=160; height=160; anchor='center'; extensionColor='transparent' } |
    ConvertTo-Json -Compress
& $invoke -CliArgs @('run', (Join-Path $work 'frame-00.png'),
    '--cmd', 'image.canvasSize', '--params', $pad,
    '--out', (Join-Path $work 'padded.png'))
```

`imageSize` resamples pixels; `canvasSize` changes the canvas. **Always set `extensionColor:'transparent'` for sprites**: the documented default is `background`.

Anchors: `topLeft`, `top`, `topRight`, `left`, `center`, `right`, `bottomLeft`, `bottom`, `bottomRight`.

### Trim transparent outer space

```powershell
& $invoke -CliArgs @('run', (Join-Path $work 'frame-00.png'),
    '--cmd', 'image.trim', '--params', '{"basedOn":"transparent"}',
    '--out', (Join-Path $work 'trimmed.png'))
```

Do not independently trim-and-fit animation frames unless a common anchor and scale are preserved. That can introduce jumping or inconsistent sizes. Very faint nonzero-alpha pixels can also keep more padding than expected; inspect the result instead of guessing its visible bounds.

### Create a transparent document

```powershell
& $invoke -CliArgs @('run', '--new',
    '{"width":64,"height":64,"background":"transparent","mode":"rgb","depth":8}',
    '--out', (Join-Path $work 'transparent.png'))
```

The documented default new-document background is **white**. Request transparent explicitly.

### Convert without discarding transparency

```powershell
& $invoke -CliArgs @('convert', (Join-Path $work 'frame-00.png'),
    (Join-Path $work 'frame-00.webp'))
& $invoke -CliArgs @('convert', (Join-Path $work 'frame-00.webp'),
    (Join-Path $work 'roundtrip.png'))
```

PNG and WebP preserve transparency in the tested path. WebP is **lossless when `--quality` is omitted**. Supplying a quality selects lossy WebP, even when that quality is 100. JPEG does not preserve an alpha channel.

Use `.pcraft` to keep an editable native master. PNG exports composite the visible layers; a warning that layers/masks were flattened is expected for that export, not proof that transparency was lost.

### Batch square pixel-art frames

Included action file: [pixel-art-128.actions.json](../tools/photocraft/pixel-art-128.actions.json).

```json
{"steps":[["image.imageSize",{"width":128,"height":128,"resample":"nearest"}]]}
```

```powershell
& $invoke -CliArgs @('batch',
    '--actions', (Join-Path $root 'tools\photocraft\pixel-art-128.actions.json'),
    '--in', (Join-Path $work 'batch-input'),
    '--out', (Join-Path $work 'batch-output'), '--format', 'png')
```

This intentionally forces a square output; use it for square frames. Batch also accepts bare command IDs, `[id,params]` pairs and `{command,params}` steps. The MCP `command_batch` format is different: its step key is `id`.

An Actions set containing multiple named actions needs `--action NAME`. Photoshop `.atn` and `.pcdroplet` support is advertised by the CLI help but was not exercised in this verification.

## Exact sprite-sheet normalization: tested lightning example

The supplied `Eight-Frame Pixel Lightning Strike.png` was **1774×887**, arranged **4 columns × 2 rows**. Its nominal cell is 443.5 pixels, not an integer. Uniform 444px source crops would include neighboring pixels or extend beyond the image.

[Export-SpriteSheet.ps1](../tools/photocraft/Export-SpriteSheet.ps1) solves this with PhotoCraft:

1. Inspect actual dimensions.
2. Calculate non-overlapping integer crop edges using round-half-away-from-zero.
3. Crop every frame independently, row-major.
4. Pad smaller cells to the requested common size using transparent bottom-center anchoring.
5. Place frames at exact centers on a transparent output sheet with `fit:false`, `scale:100`, `smartObject:false`.
6. Export PNG. Original pixels are not resampled.

```powershell
& (Join-Path $root 'tools\photocraft\Export-SpriteSheet.ps1') `
    -Source $source `
    -Out (Join-Path $root 'assets\sprites\lightning-strike-8.png') `
    -Columns 4 -Rows 2 -CellSize 444
```

The output is **1776×888**, with **eight exact 444×444 cells**. Source X edges were `0,444,887,1331,1774`; Y edges were `0,444,887`. The script preserves the original and refuses an existing output. Choose a fresh output when repeating a test.

The normalizer is for evenly arranged grids. It does not infer irregular frame locations, remove baked-in labels/backgrounds, or fix artwork that already crosses into another cell. Inspect the source before declaring its grid.

Frame intermediates remain under an ignored `build/photocraft-sprites-*` directory for inspection. The returned object contains that directory and output dimensions. A too-small `CellSize` is rejected instead of clipping the artwork.

PhotoCraft output is an offline asset-processing step. The game does not need PhotoCraft installed at runtime.

## Persistent JSON-line server

This mode avoids shell JSON arguments and keeps documents open between requests. Start:

```powershell
& $pc serve --automation-read-root $root --automation-write-root $work
```

Send one JSON object per stdin line. Each response has the same `id` and an `ok` boolean. This sequence was verified:

```json
{"id":1,"method":"doc.open","params":{"path":"D:/Development/ballwars/assets/sprites/Eight-Frame Pixel Lightning Strike.png"}}
{"id":2,"method":"doc.inspect","params":{}}
{"id":3,"method":"engine.execute","params":{"command":"image.imageSize","params":{"width":64,"height":32,"resample":"nearest"}}}
{"id":4,"method":"doc.save","params":{"path":"D:/Development/ballwars/build/your-test-folder/serve-test.png"}}
```

Create the output folder and substitute the actual granted write root. Use `methods` to list available protocol methods. Verified examples: `doc.open`, `doc.inspect`, `engine.execute`, `doc.save`.

Stdio needs no control token. Optional `serve --port PORT` binds to `127.0.0.1`; token/token-file options are documented by `serve --help`. A socket/desktop bridge was not started during this verification.

Protocol operations can return `ok:false` while the process exits normally. Inspect every response. A path outside the granted read root was rejected in testing.

## MCP integration for another AI

The installed MCP server successfully completed initialization and `tools/list` with protocol version `2025-06-18`.

Example generic MCP client configuration—adapt the configuration container to the particular client:

```json
{
  "mcpServers": {
    "photocraft": {
      "command": "C:\\Program Files\\PhotoCraft\\photocraft-cli.exe",
      "args": [
        "mcp",
        "--automation-read-root", "D:\\Development\\ballwars",
        "--automation-write-root", "D:\\Development\\ballwars\\build\\photocraft-output"
      ]
    }
  }
}
```

Create the output directory first. Omitted roots deny that direction of file access. Relative paths are resolved beneath the corresponding root; absolute paths must remain inside it.

Recommended tool flow:

1. `doc_open({"path":"assets/sprites/example.png"})`.
2. `command_list(...)` to discover IDs/parameter docs; inspect the client's advertised schema for any filter options.
3. `command_run({"id":"image.crop","params":{"x":0,"y":0,"width":444,"height":444}})`.
4. `doc_inspect({})` and `render_preview({"max_side":1024})`.
5. `doc_save({"path":"processed.png"})` to export beneath the write root.

For fewer round trips, `command_batch` takes:

```json
{"steps":[{"id":"image.imageSize","params":{"width":128,"height":128,"resample":"nearest"}}],"stop_on_error":true}
```

It is **not a transaction**: earlier successful edits remain applied if a later step fails. Long commands can use `wait:false`, then `jobs_list`/`jobs_cancel`. Prefer capability-scoped file tools such as `doc_place`/`doc_export_layers` in MCP mode rather than assuming raw file-engine commands have unrestricted path access.

Other discovered tools include `doc_new`, `doc_select`, `doc_close`, `doc_export`, `doc_render_preview`, `session_list`, and data-set/smart-object tools. Live `ui_*` tools require bridge mode; they are not ordinary headless drawing tools. MCP resources advertised by the server include `photocraft://document` and `photocraft://commands`.

## Failure handling and verification

- Preserve source files; use new outputs. `run`/`convert` refuse identical input/output unless `--in-place` is supplied. Do not add `--in-place` without explicit authorization to replace the source.
- Batch similarly refuses an identical input/output folder without `--in-place`. Different existing output filenames still deserve an explicit preflight; do not assume every command has the same overwrite guard.
- `run` with a valid crop followed by an unknown command returned exit code 1 and did not create its requested output. Inspect the failed command; do not continue as if an image was produced.
- JSON parse errors in PowerShell 5.1 usually mean native argument quoting was lost. Use the wrapper, JSON-line server, or MCP rather than guessing escaped strings.
- `channels.alpha:[]` in `info` means no separate named alpha channels; it does **not** prove that layer pixels are opaque. Verify pixel alpha or visually inspect an exported PNG.
- Verify dimensions, frame count, transparent corners, visible contents, common anchors, and the app's sprite-loader contract. Inspect before/after images.
- For this test set: cropped frame was 128×128; transparent padded output was 160×160; both had corner alpha 0 and the same 3110 nonzero-alpha pixels. A PNG→lossless WebP→PNG round trip also retained that visible-pixel count. A new transparent 64×64 PNG contained zero visible pixels.
- Same-path conversion returned exit code 1 and the supplied source's SHA-256 stayed unchanged.
- Two-image batch returned `2 succeeded, 0 failed`. Layer placement produced exact adjacent 128px cells in a 256×128 sheet. Eight-frame normalization produced the exact 1776×888 output described above.
- CLI help and registry are authoritative for this installation. Recheck `--version` and the relevant command schemas after upgrades. Do not imply that all 940 commands, every file format, a desktop bridge, or a particular AI client's configuration were end-to-end tested.

## Copyable instructions for the next AI

> Use the installed PhotoCraft CLI for image edits. Read this handoff and inspect the current command schema before acting. Use the PowerShell wrapper or MCP/JSON-line mode to preserve JSON arguments. Keep supplied originals, write new PNG outputs, preserve transparency, use nearest-neighbor for pixel art, and crop sprite frames before resampling. For animation sheets preserve consistent cells and anchors. Inspect warnings, exit codes, dimensions, alpha and rendered results. If new illustrated artwork is needed, send the user a prompt; do not call an AI image-generation service without their explicit instruction.
