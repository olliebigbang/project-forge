(() => {
  const nativeFetch = window.fetch.bind(window);

  window.fetch = async (input, init) => {
    const requestedUrl = new URL(
      input instanceof Request ? input.url : String(input),
      window.location.href,
    );

    if (!requestedUrl.pathname.endsWith("/index.wasm")) {
      return nativeFetch(input, init);
    }

    const chunks = [];
    for (let index = 0; index < 2; index += 1) {
      const chunkUrl = new URL(requestedUrl);
      chunkUrl.pathname += `.part${index}`;
      const response = await nativeFetch(chunkUrl.toString(), {
        credentials: "same-origin",
        cache: "default",
      });
      if (!response.ok) {
        throw new Error(`Unable to load WebAssembly chunk ${index}: HTTP ${response.status}`);
      }
      chunks.push(await response.arrayBuffer());
    }

    return new Response(new Blob(chunks, { type: "application/wasm" }), {
      status: 200,
      headers: { "Content-Type": "application/wasm" },
    });
  };
})();

