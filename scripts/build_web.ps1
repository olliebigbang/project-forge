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

Write-Host "Exporting Project Forge M1B1 Web build..." -ForegroundColor Cyan
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

# Allow iPhone Safari to report notch/rounded-corner safe-area insets to the
# runtime bridge. Godot's generated shell omits viewport-fit by default.
$html = Get-Content -Raw -Encoding UTF8 -LiteralPath $outputFile
$html = $html.Replace(
    'width=device-width, user-scalable=no, initial-scale=1.0',
    'width=device-width, user-scalable=no, initial-scale=1.0, viewport-fit=cover'
)
$guardPath = Join-Path $PSScriptRoot "web_canvas_guard.js"
$inputPath = Join-Path $PSScriptRoot "web_mobile_input.js"
foreach ($webScript in @($guardPath, $inputPath)) {
    if (-not (Test-Path -LiteralPath $webScript)) {
        throw "Missing Web bootstrap script: $webScript"
    }
}
$guard = Get-Content -Raw -Encoding UTF8 -LiteralPath $guardPath
$mobileInput = Get-Content -Raw -Encoding UTF8 -LiteralPath $inputPath
$guardTag = "<script data-forge-canvas-guard>`n$guard`n</script>`n<script data-forge-mobile-input>`n$mobileInput`n</script>"
$engineTag = '<script src="index.js"></script>'
if (-not $html.Contains($engineTag)) {
    throw "Godot HTML shell is missing the engine script tag."
}
$html = $html.Replace($engineTag, "$guardTag`n`t`t$engineTag")
if (-not $html.Contains('"canvasResizePolicy":0')) {
    throw "Godot Web export must use JavaScript-managed canvas resize policy 0."
}
[System.IO.File]::WriteAllText($outputFile, $html, [System.Text.UTF8Encoding]::new($false))

Write-Host "Web build ready at $outputFile" -ForegroundColor Green
