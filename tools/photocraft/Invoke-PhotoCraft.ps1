<#
.SYNOPSIS
Runs PhotoCraft CLI with reliable Windows native argument quoting, including JSON.
.EXAMPLE
  & .\tools\photocraft\Invoke-PhotoCraft.ps1 -CliArgs @('info', 'C:\Images\sprite.png')
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]] $CliArgs,
    [string] $Executable = 'C:\Program Files\PhotoCraft\photocraft-cli.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    throw "PhotoCraft CLI was not found: $Executable"
}

function ConvertTo-WindowsNativeArgument {
    param([AllowEmptyString()][string] $Value)
    # Windows CRT quoting: double backslashes before quotes and before the
    # closing quote. JSON and paths are data, never shell expressions.
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $Executable
$startInfo.Arguments = (($CliArgs | ForEach-Object {
    ConvertTo-WindowsNativeArgument -Value $_
}) -join ' ')
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
try {
    if (-not $process.Start()) { throw 'PhotoCraft CLI did not start.' }
    # Drain both streams concurrently to avoid pipe deadlocks.
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $outputText = $outputTask.GetAwaiter().GetResult()
    $errorText = $errorTask.GetAwaiter().GetResult()
    if ($outputText) { Write-Output -NoEnumerate $outputText }
    if ($errorText) { [Console]::Error.Write($errorText) }
    $photoCraftExitCode = $process.ExitCode
} finally {
    $process.Dispose()
}
exit $photoCraftExitCode
