# Project Forge M1A Web build

This archive is the standalone Godot Web export. Browsers cannot run the WASM
build by double-clicking `index.html`; it must be served over HTTP.

On Windows with Node.js installed:

```powershell
./START_WEB.ps1
```

Then open `http://localhost:8060`. Use `./START_WEB.ps1 -Port 9000` to choose a
different port. Stop the server with `Ctrl+C`.

This v9 bundle contains Compact Landscape, the native Web Description input,
explicit text clear, and RESET behavior. It is the offline fallback for the same
build deployed after PR/CI.

This bundle contains no API key and makes no paid AI request.
