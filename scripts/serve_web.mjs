import { createServer } from "node:http";
import { createReadStream, statSync } from "node:fs";
import { extname, join, normalize, resolve } from "node:path";
import { handleCompileWeapon } from "../hosting/weapon_interpreter.mjs";

const argumentsList = process.argv.slice(2);
const option = (name, fallback) => {
  const index = argumentsList.indexOf(name);
  return index >= 0 ? argumentsList[index + 1] : fallback;
};

const root = resolve(option("--root", "build/web"));
const port = Number(option("--port", "8060"));
const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

async function serveApi(request, response) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 16384) {
      response.writeHead(413, { "content-type": "application/json" }).end('{"error":"request_too_large"}');
      return;
    }
    chunks.push(chunk);
  }
  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers)) {
    if (Array.isArray(value)) value.forEach((entry) => headers.append(name, entry));
    else if (value !== undefined) headers.set(name, value);
  }
  const url = `http://${request.headers.host ?? `localhost:${port}`}${request.url}`;
  const workerRequest = new Request(url, {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : Buffer.concat(chunks),
  });
  const workerResponse = await handleCompileWeapon(workerRequest, {
    WEAPON_AI_PROVIDER: "deterministic",
    WEAPON_INTERPRETER_TEST_MODE: "true",
  });
  const outgoing = {};
  workerResponse.headers.forEach((value, name) => { outgoing[name] = value; });
  response.writeHead(workerResponse.status, outgoing);
  response.end(Buffer.from(await workerResponse.arrayBuffer()));
}

const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  if (pathname === "/api/compile-weapon") {
    try {
      await serveApi(request, response);
    } catch (error) {
      console.error("Weapon interpreter preview route failed:", error?.message ?? error);
      response.writeHead(500, { "content-type": "application/json" }).end('{"error":"internal_error"}');
    }
    return;
  }
  const relative = pathname === "/" ? "index.html" : normalize(pathname).replace(/^[/\\]+/, "");
  const filePath = resolve(join(root, relative));
  if (!filePath.startsWith(root)) {
    response.writeHead(403).end("Forbidden");
    return;
  }
  try {
    if (!statSync(filePath).isFile()) throw new Error("Not a file");
    response.writeHead(200, {
      "Content-Type": mime[extname(filePath)] ?? "application/octet-stream",
      "Cache-Control": "no-store",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
    });
    createReadStream(filePath).pipe(response);
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" }).end("Not found");
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Project Forge Web preview: http://localhost:${port}`);
  console.log(`Serving ${root}`);
});
