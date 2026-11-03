# Ball Wars Phase 1 reproducible local verification (Windows PowerShell 7+)
# Usage: pwsh -File .\tool\phase1\verify_phase1.ps1 -BaselineZip C:\path\ballwars_batch18_center_wall_contact_cumulative.zip -PatchZip C:\path\bw_task1_trap_controls_cumulative_patch33.zip
# Creates an isolated temporary checkout. Never writes into the user's main repo.
param(
  [Parameter(Mandatory=$true)][string]$BaselineZip,
  [Parameter(Mandatory=$true)][string]$PatchZip,
  [string]$OutputDirectory = (Join-Path $PWD 'phase1_verification')
)
$ErrorActionPreference = 'Stop'
$baseline = (Resolve-Path -LiteralPath $BaselineZip).Path
$patch = (Resolve-Path -LiteralPath $PatchZip).Path
if ((Get-Item -LiteralPath $baseline).Length -ne 4822757) { throw 'Incorrect Batch 18 baseline size (expected 4,822,757 bytes).' }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter SDK not found on PATH. Install/configure Flutter before verification.' }
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Output directory already exists; refusing to overwrite: ' + $OutputDirectory }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$workspace = (Resolve-Path -LiteralPath $OutputDirectory).Path
$src = Join-Path $workspace 'source'
New-Item -ItemType Directory -Path $src | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($baseline, $src)
# Verify each patch entry's SHA-256 against the embedded manifest before overlay.
$archive = [System.IO.Compression.ZipFile]::OpenRead($patch)
try {
  $manifestEntry = $archive.GetEntry('BW_TASK1_MANIFEST.json')
  if ($null -eq $manifestEntry) { throw 'Missing patch manifest' }
  $reader = New-Object System.IO.StreamReader($manifestEntry.Open())
  try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
  if ($manifest.baseline_bytes -ne 4822757) { throw 'Unexpected baseline metadata in patch manifest' }
  $expected = @($manifest.files.PSObject.Properties.Name)
  foreach ($entry in $archive.Entries) {
    if ($entry.FullName -eq 'BW_TASK1_MANIFEST.json') { continue }
    if ($entry.FullName -notin $expected) { throw "Unlisted patch entry: $($entry.FullName)" }
    if ($entry.FullName.StartsWith('/') -or $entry.FullName.Contains('..') -or $entry.FullName.Contains('\\')) { throw "Unsafe patch entry: $($entry.FullName)" }
    $stream = $entry.Open()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $digest = [Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant() } finally { $stream.Dispose(); $sha.Dispose() }
    if ($digest -ne $manifest.files.($entry.FullName).sha256) { throw "Hash mismatch: $($entry.FullName)" }
    if ($entry.Length -ne $manifest.files.($entry.FullName).bytes) { throw "Size mismatch: $($entry.FullName)" }
  }
  foreach ($name in $expected) { if ($null -eq $archive.GetEntry($name)) { throw "Missing patch entry: $name" } }
} finally { $archive.Dispose() }
[System.IO.Compression.ZipFile]::ExtractToDirectory($patch, $src, $true)
Push-Location $src
try {
  & flutter pub get 2>&1 | Tee-Object (Join-Path $workspace 'pub_get.log')
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  & flutter analyze 2>&1 | Tee-Object (Join-Path $workspace 'analyze.log')
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed; inspect analyze.log' }
  $tests = @(
    Get-ChildItem 'test/features/arena_simulation/application/trap_*_test.dart' -File | ForEach-Object { $_.FullName }
    (Resolve-Path 'test/features/arena_simulation/application/arena_trap_cleanup_test.dart').Path
    (Resolve-Path 'test/features/arena_simulation/domain/trap_control_config_test.dart').Path
    (Resolve-Path 'test/features/settings/power_up_tuning_screen_test.dart').Path
  )
  & flutter test --reporter expanded @tests 2>&1 | Tee-Object (Join-Path $workspace 'phase1_tests.log')
  if ($LASTEXITCODE -ne 0) { throw 'Phase 1 regression tests failed; inspect phase1_tests.log' }
  'PHASE 1 LOCAL VERIFICATION PASSED' | Set-Content (Join-Path $workspace 'result.txt')
} catch {
  ('FAILED: ' + $_.Exception.Message) | Set-Content (Join-Path $workspace 'result.txt')
  throw
} finally { Pop-Location }
