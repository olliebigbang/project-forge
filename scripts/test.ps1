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
    $logDirectory = Join-Path $repoRoot "output\godot-test-logs"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $safeLabel = $Label -replace "[^A-Za-z0-9]+", "-"
    $logFile = Join-Path $logDirectory ("{0}-{1}.log" -f $safeLabel, [guid]::NewGuid().ToString("N"))
    $effectiveArguments = @($Arguments) + @("--log-file", $logFile)
    # Windows PowerShell 5 wraps every native stderr line as an ErrorRecord and
    # turns it into a terminating exception under the script-wide Stop policy.
    # Godot can emit a non-blocking certificate-store diagnostic on stderr while
    # still returning zero. Capture the complete stream, then enforce the exit
    # code and explicit diagnostic checks below.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = @(& $script:Godot @effectiveArguments 2>&1)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode"
    }
    $diagnostics = $output -join "`n"
    $actionableDiagnostics = $diagnostics -replace "(?m)^.*ERROR: Failed to read the root certificate store\.\s*", ""
    if ($actionableDiagnostics -match "(?m)SCRIPT ERROR:|^ERROR:|FAIL  ") {
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
Invoke-GodotCheck "M2 belt combat spike tests" @(
    "--headless", "--path", $repoRoot, "--script", "res://tests/belt_combat_spike_test.gd"
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
