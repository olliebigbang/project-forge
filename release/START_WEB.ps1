[CmdletBinding()]
param([int]$Port = 8060)

$ErrorActionPreference = "Stop"
$bundleRoot = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $bundleRoot "index.html"))) {
    throw "index.html is missing from this Web bundle."
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required to run the local Web server. Install Node.js, then retry."
}

& node (Join-Path $bundleRoot "serve_web.mjs") --root $bundleRoot --port $Port
