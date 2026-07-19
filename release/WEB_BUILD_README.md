# Project Forge M1A Web build

This archive is the standalone Godot Web export. Browsers cannot run the WASM
build by double-clicking `index.html`; it must be served over HTTP.

On Windows with Node.js installed:

```powershell
./START_WEB.ps1
```

Then open `http://localhost:8060`. Use `./START_WEB.ps1 -Port 9000` to choose a
different port. Stop the server with `Ctrl+C`.

For a phone, the simplest path is the public build:

https://project-forge-weapon-lab.hongningliu0130.chatgpt.site

This bundle contains no API key and makes no paid AI request.
