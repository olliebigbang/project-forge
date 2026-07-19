[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ForgeGodot {
    $localEngine = Join-Path $repoRoot ".tools\Godot_v4.7.1-stable_win64_console.exe"
    if (Test-Path -LiteralPath $localEngine) {
        return $localEngine
    }
    foreach ($candidate in @("godot4", "godot")) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }
    throw "Godot 4.7.1 was not found. Place the console executable in .tools or install Godot 4."
}

function Invoke-GodotCheck {
    param(
        [string]$Label,
        [string[]]$Arguments
    )
    Write-Host "`n== $Label ==" -ForegroundColor Cyan
    & $script:Godot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

$script:Godot = Resolve-ForgeGodot
Write-Host "Using $script:Godot"

Invoke-GodotCheck "Project import and script parse" @(
    "--headless", "--editor", "--path", $repoRoot, "--import"
)
Invoke-GodotCheck "Deterministic unit tests" @(
    "--headless", "--path", $repoRoot, "--script", "res://tests/run_tests.gd"
)
Invoke-GodotCheck "Main-scene runtime smoke" @(
    "--headless", "--path", $repoRoot, "--quit-after", "120"
)

Write-Host "`n== Sites static worker tests ==" -ForegroundColor Cyan
& node --test (Join-Path $repoRoot "tests\static_worker.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Sites static worker tests failed with exit code $LASTEXITCODE"
}
& node --test (Join-Path $repoRoot "tests\wasm_chunk_loader.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "WASM chunk loader tests failed with exit code $LASTEXITCODE"
}

Write-Host "`nAll Project Forge M1A checks passed." -ForegroundColor Green
