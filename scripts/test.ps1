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
    $output = @(& $script:Godot @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode"
    }
    $diagnostics = $output -join "`n"
    if ($diagnostics -match "(?m)SCRIPT ERROR:|^ERROR:|FAIL  ") {
        throw "$Label emitted a script, runtime, or assertion failure despite exit code 0"
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
& node --test (Join-Path $repoRoot "tests\weapon_interpreter.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Weapon interpreter tests failed with exit code $LASTEXITCODE"
}
& node --test (Join-Path $repoRoot "tests\durable_request_guard.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Durable request guard tests failed with exit code $LASTEXITCODE"
}
& node --test (Join-Path $repoRoot "tests\anthropic_weapon_adapter.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Anthropic weapon adapter tests failed with exit code $LASTEXITCODE"
}
& node --test (Join-Path $repoRoot "tests\provider_budget_guard.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Provider budget guard tests failed with exit code $LASTEXITCODE"
}
& node --test (Join-Path $repoRoot "tests\m1b1_anthropic_safety_regression.test.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Anthropic safety regression tests failed with exit code $LASTEXITCODE"
}

Write-Host "`nAll Project Forge M1A + M1B1 checks passed." -ForegroundColor Green
