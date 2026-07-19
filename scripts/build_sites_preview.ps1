[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$webBuild = Join-Path $repoRoot "build\web"
$distRoot = Join-Path $repoRoot "dist"
$distClient = Join-Path $distRoot "client"
$distServer = Join-Path $distRoot "server"

& (Join-Path $PSScriptRoot "build_web.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Godot Web build failed before Sites packaging."
}

$resolvedDist = [System.IO.Path]::GetFullPath($distRoot)
$expectedDist = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "dist"))
if ($resolvedDist -ne $expectedDist) {
    throw "Refusing to replace an unexpected dist directory: $resolvedDist"
}
if (Test-Path -LiteralPath $distRoot) {
    Remove-Item -LiteralPath $distRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $distClient, $distServer | Out-Null
Get-ChildItem -LiteralPath $webBuild -File |
    Where-Object { $_.Name -ne ".gitkeep" -and $_.Extension -ne ".import" } |
    Copy-Item -Destination $distClient -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\static_worker.mjs") -Destination (Join-Path $distServer "index.js") -Force

$hostingFile = Join-Path $repoRoot ".openai\hosting.json"
if (-not (Test-Path -LiteralPath $hostingFile)) {
    throw "Missing .openai/hosting.json"
}

$required = @(
    "dist\server\index.js",
    "dist\client\index.html",
    "dist\client\index.js",
    "dist\client\index.wasm",
    "dist\client\index.pck"
)
foreach ($relativePath in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath))) {
        throw "Sites build is incomplete: missing $relativePath"
    }
}

Write-Host "Sites preview bundle ready at $distRoot" -ForegroundColor Green

