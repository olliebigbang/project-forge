/**
 * Sites/Cloudflare worker for the generated Godot Web build.
 * The ASSETS binding serves files copied to dist/client by build_sites_preview.ps1.
 */
import { handleCompileWeapon } from "./weapon_interpreter.mjs";

const SECURITY_HEADERS = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
  "Cross-Origin-Resource-Policy": "same-origin",
  "X-Content-Type-Options": "nosniff",
};

function withSecurityHeaders(response) {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    headers.set(name, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/api/compile-weapon") {
      return withSecurityHeaders(await handleCompileWeapon(request, env));
    }
    if (url.pathname === "/") {
      url.pathname = "/index.html";
    }

    const assetResponse = await env.ASSETS.fetch(new Request(url, request));
    const headers = new Headers(assetResponse.headers);
    for (const [name, value] of Object.entries(SECURITY_HEADERS)) headers.set(name, value);
    const isRuntimePayload =
      url.pathname.startsWith("/index.") || url.pathname === "/wasm_chunk_loader.js";
    if (url.pathname === "/index.html") {
      headers.set("Cache-Control", "no-store");
    } else if (isRuntimePayload) {
      // Godot export filenames are stable across releases. Revalidate them so an
      // in-place deployment cannot pair fresh HTML with a stale PCK/JS/WASM chunk.
      headers.set("Cache-Control", "no-cache, must-revalidate");
    } else {
      headers.set("Cache-Control", "public, max-age=3600");
    }

    return new Response(assetResponse.body, {
      status: assetResponse.status,
      statusText: assetResponse.statusText,
      headers,
    });
  },
};
