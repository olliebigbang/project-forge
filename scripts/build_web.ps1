[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$localEngine = Join-Path $repoRoot ".tools\Godot_v4.7.1-stable_win64_console.exe"

if (Test-Path -LiteralPath $localEngine) {
    $godot = $localEngine
} else {
    $command = Get-Command "godot4" -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command "godot" -ErrorAction SilentlyContinue
    }
    if (-not $command) {
        throw "Godot 4.7.1 was not found. Place it in .tools or install Godot 4."
    }
    $godot = $command.Source
}

$outputDirectory = Join-Path $repoRoot "build\web"
$outputFile = Join-Path $outputDirectory "index.html"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

Write-Host "Exporting Project Forge M1A Web build..." -ForegroundColor Cyan
& $godot --headless --path $repoRoot --export-release "Web" $outputFile
if ($LASTEXITCODE -ne 0) {
    throw "Godot Web export failed with exit code $LASTEXITCODE"
}

$required = @("index.html", "index.js", "index.wasm", "index.pck")
foreach ($file in $required) {
    $path = Join-Path $outputDirectory $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Web export is incomplete: missing $file"
    }
}

Write-Host "Web build ready at $outputFile" -ForegroundColor Green
