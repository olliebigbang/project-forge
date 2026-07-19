[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $repoRoot "release"
$stagingRoot = Join-Path $releaseRoot "staging"
$archivePath = Join-Path $releaseRoot "Project-Forge-M1A-iPhone-Touch-Fix-Web.zip"
$expectedStaging = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "release\staging"))
$resolvedStaging = [System.IO.Path]::GetFullPath($stagingRoot)

if ($resolvedStaging -ne $expectedStaging) {
    throw "Refusing to replace unexpected staging directory: $resolvedStaging"
}
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot "build\web\index.html"))) {
    & (Join-Path $PSScriptRoot "build_web.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Web build failed." }
}
if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repoRoot "build\web") -File |
    Where-Object { $_.Name -ne ".gitkeep" -and $_.Extension -ne ".import" } |
    Copy-Item -Destination $stagingRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "serve_web.mjs") -Destination $stagingRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "START_WEB.ps1") -Destination $stagingRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "WEB_BUILD_README.md") -Destination $stagingRoot -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot "BUILD_ID.txt") -Destination $stagingRoot -Force

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $archivePath -CompressionLevel Optimal

foreach ($required in @("index.html", "index.js", "index.wasm", "index.pck", "START_WEB.ps1", "serve_web.mjs", "BUILD_ID.txt")) {
    if (-not (Test-Path -LiteralPath (Join-Path $stagingRoot $required))) {
        throw "Release bundle is incomplete: missing $required"
    }
}
Write-Host "Downloadable Web bundle ready at $archivePath" -ForegroundColor Green
