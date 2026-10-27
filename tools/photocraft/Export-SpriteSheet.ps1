<#
.SYNOPSIS
Normalizes a sprite sheet into isolated, equal square cells using PhotoCraft CLI.
Preserves source pixels; smaller cells receive transparent padding, not scaling.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Source,
    [Parameter(Mandatory = $true)][string] $Out,
    [ValidateRange(1, 128)][int] $Columns = 4,
    [ValidateRange(1, 128)][int] $Rows = 2,
    [ValidateRange(0, 16384)][int] $CellSize = 0,
    [string] $Executable = 'C:\Program Files\PhotoCraft\photocraft-cli.exe'
)
$ErrorActionPreference = 'Stop'
$wrapper = Join-Path $PSScriptRoot 'Invoke-PhotoCraft.ps1'
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$outputPath = [IO.Path]::GetFullPath($Out)
if ($sourcePath -eq $outputPath -or (Test-Path -LiteralPath $outputPath)) {
    throw 'Choose a new output path; this command does not overwrite files.'
}
$infoText = & $wrapper -Executable $Executable -CliArgs @('info', '--compact', $sourcePath)
if ($LASTEXITCODE -ne 0) { throw 'PhotoCraft could not inspect the source.' }
$info = $infoText | ConvertFrom-Json
$minimumCell = [int][Math]::Ceiling([Math]::Max($info.width / $Columns, $info.height / $Rows))
if ($CellSize -eq 0) { $CellSize = $minimumCell }
if ($CellSize -lt $minimumCell) {
    throw "CellSize must be at least $minimumCell to preserve the original pixels."
}
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$workDir = Join-Path (Join-Path $repoRoot 'build') ('photocraft-sprites-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDir | Out-Null
$placeSteps = New-Object 'System.Collections.Generic.List[string]'
for ($row = 0; $row -lt $Rows; $row++) {
    for ($column = 0; $column -lt $Columns; $column++) {
        $left = [int][Math]::Round($column * $info.width / $Columns, [MidpointRounding]::AwayFromZero)
        $right = [int][Math]::Round(($column + 1) * $info.width / $Columns, [MidpointRounding]::AwayFromZero)
        $top = [int][Math]::Round($row * $info.height / $Rows, [MidpointRounding]::AwayFromZero)
        $bottom = [int][Math]::Round(($row + 1) * $info.height / $Rows, [MidpointRounding]::AwayFromZero)
        $index = $row * $Columns + $column
        $framePath = Join-Path $workDir ('frame-{0:D2}.png' -f $index)
        $crop = @{ x=$left; y=$top; width=($right-$left); height=($bottom-$top) } | ConvertTo-Json -Compress
        $padding = @{ width=$CellSize; height=$CellSize; anchor='bottom'; extensionColor='transparent' } | ConvertTo-Json -Compress
        & $wrapper -Executable $Executable -CliArgs @('run', $sourcePath,
            '--cmd', 'image.crop', '--params', $crop,
            '--cmd', 'image.canvasSize', '--params', $padding, '--out', $framePath) | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "PhotoCraft failed on frame $index. Inspect $workDir" }
        $placement = @{ path=$framePath; scale=100; fit=$false; smartObject=$false;
            center=@(($column*$CellSize+$CellSize/2), ($row*$CellSize+$CellSize/2)) } | ConvertTo-Json -Compress
        $placeSteps.Add('--cmd')
        $placeSteps.Add('file.placeEmbedded')
        $placeSteps.Add('--params')
        $placeSteps.Add($placement)
    }
}
$newDocument = @{ width=($Columns*$CellSize); height=($Rows*$CellSize);
    background='transparent'; mode='rgb'; depth=8 } | ConvertTo-Json -Compress
$finalArgs = @('run', '--new', $newDocument) + $placeSteps.ToArray() + @('--out', $outputPath)
& $wrapper -Executable $Executable -CliArgs $finalArgs | Out-Null
if ($LASTEXITCODE -ne 0) { throw "PhotoCraft could not assemble the sheet. Inspect $workDir" }
[pscustomobject]@{ Path=$outputPath; Width=($Columns*$CellSize); Height=($Rows*$CellSize);
    Frames=($Columns*$Rows); CellSize=$CellSize; FrameDirectory=$workDir }
