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
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\weapon_contract.mjs") -Destination (Join-Path $distServer "weapon_contract.mjs") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\weapon_schema.mjs") -Destination (Join-Path $distServer "weapon_schema.mjs") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\durable_request_guard.mjs") -Destination (Join-Path $distServer "durable_request_guard.mjs") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\weapon_interpreter.mjs") -Destination (Join-Path $distServer "weapon_interpreter.mjs") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "hosting\wasm_chunk_loader.js") -Destination (Join-Path $distClient "wasm_chunk_loader.js") -Force

# Sites has a 25 MB single-file limit. Split the Godot WASM into two byte-exact
# chunks and install a browser-side fetch shim that reconstructs the response.
$wasmPath = Join-Path $distClient "index.wasm"
$chunkSize = 20MB
$inputStream = [System.IO.File]::OpenRead($wasmPath)
try {
    $buffer = New-Object byte[] (1MB)
    for ($chunkIndex = 0; $chunkIndex -lt 2; $chunkIndex++) {
        $chunkPath = "$wasmPath.part$chunkIndex"
        $outputStream = [System.IO.File]::Create($chunkPath)
        try {
            $remaining = [Math]::Min($chunkSize, $inputStream.Length - $inputStream.Position)
            while ($remaining -gt 0) {
                $requested = [Math]::Min($buffer.Length, $remaining)
                $read = $inputStream.Read($buffer, 0, $requested)
                if ($read -le 0) {
                    throw "Unexpected end of WebAssembly while creating chunk $chunkIndex"
                }
                $outputStream.Write($buffer, 0, $read)
                $remaining -= $read
            }
        } finally {
            $outputStream.Dispose()
        }
    }
    if ($inputStream.Position -ne $inputStream.Length) {
        throw "WebAssembly needs more than two Sites chunks."
    }
} finally {
    $inputStream.Dispose()
}
Remove-Item -LiteralPath $wasmPath -Force

$htmlPath = Join-Path $distClient "index.html"
$html = Get-Content -Raw -Encoding UTF8 -LiteralPath $htmlPath
$loaderTag = '<script src="wasm_chunk_loader.js"></script>'
if (-not $html.Contains($loaderTag)) {
    $html = $html.Replace("</head>", "$loaderTag`n</head>")
    [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))
}

$hostingFile = Join-Path $repoRoot ".openai\hosting.json"
if (-not (Test-Path -LiteralPath $hostingFile)) {
    throw "Missing .openai/hosting.json"
}

$required = @(
    "dist\server\index.js",
    "dist\server\weapon_contract.mjs",
    "dist\server\weapon_schema.mjs",
    "dist\server\durable_request_guard.mjs",
    "dist\server\weapon_interpreter.mjs",
    "dist\client\index.html",
    "dist\client\index.js",
    "dist\client\index.wasm.part0",
    "dist\client\index.wasm.part1",
    "dist\client\wasm_chunk_loader.js",
    "dist\client\index.pck"
)
foreach ($relativePath in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath))) {
        throw "Sites build is incomplete: missing $relativePath"
    }
}

Write-Host "Sites preview bundle ready at $distRoot" -ForegroundColor Green
