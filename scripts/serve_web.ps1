[CmdletBinding()]
param(
    [int]$Port = 8060
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$index = Join-Path $repoRoot "build\web\index.html"
if (-not (Test-Path -LiteralPath $index)) {
    throw "Web build not found. Run ./scripts/build_web.ps1 first."
}

& node (Join-Path $PSScriptRoot "serve_web.mjs") --root (Join-Path $repoRoot "build\web") --port $Port

