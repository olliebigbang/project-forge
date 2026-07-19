/**
 * Sites/Cloudflare worker for the generated Godot Web build.
 * The ASSETS binding serves files copied to dist/client by build_sites_preview.ps1.
 */
const SECURITY_HEADERS = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
  "Cross-Origin-Resource-Policy": "same-origin",
  "X-Content-Type-Options": "nosniff",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/") {
      url.pathname = "/index.html";
    }

    const servesPrecompressedWasm = url.pathname.endsWith(".wasm");
    if (servesPrecompressedWasm) {
      url.pathname += ".gz";
    }

    const assetResponse = await env.ASSETS.fetch(new Request(url, request));
    const headers = new Headers(assetResponse.headers);
    for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
      headers.set(name, value);
    }
    headers.set("Cache-Control", url.pathname === "/index.html" ? "no-store" : "public, max-age=3600");
    if (servesPrecompressedWasm) {
      headers.set("Content-Type", "application/wasm");
      headers.set("Content-Encoding", "gzip");
      headers.set("Vary", "Accept-Encoding");
    }

    return new Response(assetResponse.body, {
      status: assetResponse.status,
      statusText: assetResponse.statusText,
      headers,
    });
  },
};
