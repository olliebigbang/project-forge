import { mkdir, rm } from "node:fs/promises";
import { resolve } from "node:path";
import { devices, expect, test } from "@playwright/test";

const previewUrl = process.env.FORGE_PREVIEW_URL;
const expectedRelease = process.env.EXPECTED_RELEASE;
const screenshotRoot = resolve("output/playwright/smoke/screenshots");

const knownBrowserNoise = (text) =>
  text.includes("GPU stall due to ReadPixels") ||
  text.includes("CONTEXT_LOST_WEBGL") ||
  text.includes("glBlitFramebuffer") ||
  text.includes("WEBGL_polygon_mode") ||
  text ===
    "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";

const withQaMode = (rawUrl) => {
  const url = new URL(rawUrl);
  url.searchParams.set("qa", "m1b1");
  return url;
};

const waitForScreen = async (page, screen, phase) => {
  await page.waitForFunction(
    ({ expectedScreen, expectedPhase }) => {
      const state = window.__forgeM1B1Test?.state?.();
      return state?.screen === expectedScreen && state?.phase === expectedPhase;
    },
    { expectedScreen: screen, expectedPhase: phase },
    { polling: "raf", timeout: 45_000 },
  );
};

const mobileSnapshot = (page) =>
  page.evaluate(() => window.__forgeM1B1Test?.mobileInput?.() || null);

const canvasSnapshot = (page) =>
  page.evaluate(() => {
    const canvas = document.getElementById("canvas") || document.querySelector("canvas");
    if (!canvas) return null;
    const rect = canvas.getBoundingClientRect();
    const visibleWidth = Math.max(
      0,
      Math.min(rect.right, window.innerWidth) - Math.max(rect.left, 0),
    );
    const visibleHeight = Math.max(
      0,
      Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0),
    );
    const probe = document.createElement("canvas");
    probe.width = 64;
    probe.height = 36;
    const probeContext = probe.getContext("2d", { willReadFrequently: true });
    probeContext.drawImage(canvas, 0, 0, probe.width, probe.height);
    const pixels = probeContext.getImageData(
      0,
      0,
      probe.width,
      probe.height,
    ).data;
    let litSampleCount = 0;
    for (let index = 0; index < pixels.length; index += 4) {
      if (
        pixels[index + 3] > 0 &&
        pixels[index] + pixels[index + 1] + pixels[index + 2] >= 18
      ) {
        litSampleCount += 1;
      }
    }
    return {
      backingWidth: canvas.width,
      backingHeight: canvas.height,
      rect: {
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: rect.height,
      },
      visibleWidth,
      visibleHeight,
      litSampleCount,
    };
  });

test.beforeAll(async () => {
  if (!previewUrl) throw new Error("FORGE_PREVIEW_URL is required.");
  if (!expectedRelease) throw new Error("EXPECTED_RELEASE is required.");
  const parsed = new URL(previewUrl);
  const local = ["localhost", "127.0.0.1", "::1"].includes(parsed.hostname);
  if (!local && parsed.protocol !== "https:") {
    throw new Error("A non-local FORGE_PREVIEW_URL must use HTTPS.");
  }
  await rm(screenshotRoot, { recursive: true, force: true });
  await mkdir(screenshotRoot, { recursive: true });
});

test("deployed mobile Forge survives portrait, keyboard and Canvas recovery", async ({
  browser,
  page,
}) => {
  const highPriorityErrors = [];
  const criticalRequestFailures = [];

  const observePage = (observedPage) => {
    observedPage.on("console", (message) => {
      if (message.type() === "error" && !knownBrowserNoise(message.text())) {
        highPriorityErrors.push(`console: ${message.text()}`);
      }
    });
    observedPage.on("pageerror", (error) => {
      if (!knownBrowserNoise(error.message)) {
        highPriorityErrors.push(`pageerror: ${error.message}`);
      }
    });
    observedPage.on("requestfailed", (request) => {
      if (/\.(?:js|wasm|pck)(?:$|\?)/i.test(request.url())) {
        criticalRequestFailures.push(
          `${request.url()}: ${request.failure()?.errorText || "request failed"}`,
        );
      }
    });
  };
  observePage(page);

  await page.goto(withQaMode(previewUrl).href, {
    waitUntil: "domcontentloaded",
  });

  const buildIdentity = await page.locator(
    'meta[name="project-forge-build"]',
  ).getAttribute("content");
  expect(buildIdentity).toBe(expectedRelease);
  await expect
    .poll(() =>
      page.evaluate(() => window.__forgeBuildInfo?.buildId || null),
    )
    .toBe(expectedRelease);

  await waitForScreen(page, "forge", "idle");
  await page.waitForTimeout(250);

  const initialLandscapeCanvas = await canvasSnapshot(page);
  expect(initialLandscapeCanvas).not.toBeNull();
  expect(initialLandscapeCanvas.backingWidth).toBeGreaterThan(0);
  expect(initialLandscapeCanvas.backingHeight).toBeGreaterThan(0);
  expect(initialLandscapeCanvas.rect.width).toBeGreaterThanOrEqual(800);
  expect(initialLandscapeCanvas.rect.height).toBeGreaterThanOrEqual(360);
  expect(initialLandscapeCanvas.visibleWidth).toBeGreaterThanOrEqual(800);
  expect(initialLandscapeCanvas.visibleHeight).toBeGreaterThanOrEqual(360);
  expect(initialLandscapeCanvas.litSampleCount).toBeGreaterThan(20);
  await page.screenshot({
    path: resolve(screenshotRoot, "01-forge-loaded-844x390.png"),
  });

  const portraitContext = await browser.newContext({
    ...devices["iPhone 15"],
    viewport: { width: 390, height: 844 },
    screen: { width: 390, height: 844 },
  });
  const portraitPage = await portraitContext.newPage();
  observePage(portraitPage);
  await portraitPage.goto(withQaMode(previewUrl).href, {
    waitUntil: "domcontentloaded",
  });
  await waitForScreen(portraitPage, "portrait", "portrait");
  await portraitPage.screenshot({
    path: resolve(screenshotRoot, "02-portrait-gate-390x844.png"),
  });
  await expect(portraitPage.locator("#forge-description-input")).toBeHidden();
  await portraitContext.close();

  const input = page.getByRole("textbox", { name: "Weapon description" });
  const done = page.getByRole("button", { name: "Finish editing description" });
  await expect(input).toBeVisible();
  await input.tap();
  await input.fill("mobile smoke description");

  await expect
    .poll(() =>
      page.evaluate(
        () => window.__forgeM1B1Test?.state?.().description || "",
      ),
    )
    .toBe("mobile smoke description");

  const baseline = await mobileSnapshot(page);
  expect(baseline?.metrics?.canvasBackingWidth).toBeGreaterThan(0);
  expect(baseline?.metrics?.canvasBackingHeight).toBeGreaterThan(0);

  const viewportOverrideAccepted = await page.evaluate(() =>
    window.__forgeM1B1Test.setVisualViewport({
      width: 844,
      height: 190,
      offsetLeft: 0,
      offsetTop: 92,
      innerWidth: 844,
      innerHeight: 390,
      scale: 1,
    }),
  );
  expect(viewportOverrideAccepted).toBe(true);

  await expect
    .poll(async () => (await mobileSnapshot(page))?.metrics?.keyboardOpen)
    .toBe(true);
  const keyboardOpen = await mobileSnapshot(page);
  expect(keyboardOpen.metrics.canvasBackingWidth).toBe(
    baseline.metrics.canvasBackingWidth,
  );
  expect(keyboardOpen.metrics.canvasBackingHeight).toBe(
    baseline.metrics.canvasBackingHeight,
  );
  expect(keyboardOpen.metrics.canvasRect.width).toBe(
    baseline.metrics.canvasRect.width,
  );
  expect(keyboardOpen.metrics.canvasRect.height).toBe(
    baseline.metrics.canvasRect.height,
  );
  expect(keyboardOpen.inputFontSize).toBeGreaterThanOrEqual(16);
  expect(keyboardOpen.doneRect.width).toBeGreaterThanOrEqual(44);
  expect(keyboardOpen.doneRect.height).toBeGreaterThanOrEqual(44);
  await page.screenshot({
    path: resolve(screenshotRoot, "03-keyboard-open.png"),
  });

  await done.click();
  await page.evaluate(() => window.__forgeM1B1Test.clearVisualViewport());
  await expect
    .poll(async () => {
      const snapshot = await mobileSnapshot(page);
      return Boolean(
        snapshot &&
          !snapshot.metrics.textEntryActive &&
          !snapshot.metrics.keyboardOpen &&
          !snapshot.doneVisible,
      );
    })
    .toBe(true);

  const keyboardClosed = await mobileSnapshot(page);
  expect(keyboardClosed.metrics.canvasBackingWidth).toBe(
    baseline.metrics.canvasBackingWidth,
  );
  expect(keyboardClosed.metrics.canvasBackingHeight).toBe(
    baseline.metrics.canvasBackingHeight,
  );
  expect(keyboardClosed.inputValue).toBe("mobile smoke description");
  await page.screenshot({
    path: resolve(screenshotRoot, "04-keyboard-closed.png"),
  });

  await expect(input).toHaveValue("mobile smoke description");

  expect(criticalRequestFailures).toEqual([]);
  expect(highPriorityErrors).toEqual([]);
});
