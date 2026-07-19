[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$webBuild = Join-Path $repoRoot "build\web"
$distRoot = Join-Path $repoRoot "dist"
$distClient = Join-Path $distRoot "client"
$distServer = Join-Path $distRoot "server"

$resolvedDist = [System.IO.Path]::GetFullPath($distRoot)
$expectedDist = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "dist"))
if ($resolvedDist -ne $expectedDist) {
    throw "Refusing to replace an unexpected dist directory: $resolvedDist"
}
if (Test-Path -LiteralPath $distRoot) {
    Remove-Item -LiteralPath $distRoot -Recurse -Force
}

& (Join-Path $PSScriptRoot "build_web.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Godot Web build failed before Sites packaging."
}

New-Item -ItemType Directory -Force -Path $distClient, $distServer | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $distRoot ".gdignore") | Out-Null
Get-ChildItem -LiteralPath $webBuild -File |
    Where-Object { $_.Name -ne ".gitkeep" -and $_.Extension -ne ".import" } |
    Copy-Item -Destination $distClient -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\static_worker.mjs") -Destination (Join-Path $distServer "index.js") -Force

# Sites has a 25 MB single-file limit. Store the Godot WASM precompressed and
# let the edge worker expose it at the original /index.wasm request path.
$wasmPath = Join-Path $distClient "index.wasm"
$compressedWasmPath = "$wasmPath.gz"
$inputStream = [System.IO.File]::OpenRead($wasmPath)
$outputStream = [System.IO.File]::Create($compressedWasmPath)
try {
    $gzipStream = [System.IO.Compression.GZipStream]::new(
        $outputStream,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $true
    )
    try {
        $inputStream.CopyTo($gzipStream)
    } finally {
        $gzipStream.Dispose()
    }
} finally {
    $inputStream.Dispose()
    $outputStream.Dispose()
}
if ((Get-Item -LiteralPath $compressedWasmPath).Length -ge 25MB) {
    throw "Compressed WebAssembly still exceeds the Sites 25 MB file limit."
}
Remove-Item -LiteralPath $wasmPath -Force

$hostingFile = Join-Path $repoRoot ".openai\hosting.json"
if (-not (Test-Path -LiteralPath $hostingFile)) {
    throw "Missing .openai/hosting.json"
}

$required = @(
    "dist\server\index.js",
    "dist\client\index.html",
    "dist\client\index.js",
    "dist\client\index.wasm.gz",
    "dist\client\index.pck"
)
foreach ($relativePath in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath))) {
        throw "Sites build is incomplete: missing $relativePath"
    }
}

Write-Host "Sites preview bundle ready at $distRoot" -ForegroundColor Green
