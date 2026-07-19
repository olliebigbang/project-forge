[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$localEngine = Join-Path $repoRoot ".tools\Godot_v4.7.1-stable_win64.exe"

if (-not (Test-Path -LiteralPath $localEngine)) {
    $command = Get-Command "godot4" -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command "godot" -ErrorAction SilentlyContinue
    }
    if (-not $command) {
        throw "Godot 4 was not found. Place the executable in .tools or install Godot 4."
    }
    $localEngine = $command.Source
}

& $localEngine --path $repoRoot

