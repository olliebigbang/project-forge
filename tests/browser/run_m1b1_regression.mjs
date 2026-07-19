import { readFile, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";

const require = createRequire(import.meta.url);
const [browserName = "chromium", targetUrl = "http://127.0.0.1:8060/", outputPath = ""] = process.argv.slice(2);
const modulePath = process.env.PLAYWRIGHT_MODULE_PATH || "playwright";
const playwright = require(modulePath);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const scriptName = browserName === "webkit"
  ? "m1b1_webkit_regression.js"
  : "m1b1_mobile_regression.js";
const source = await readFile(new URL(scriptName, import.meta.url), "utf8");
const regression = Function(`"use strict"; return (${source});`)();

const browser = await browserType.launch({ headless: true });
try {
  const device = playwright.devices["iPhone 15"];
  const context = await browser.newContext({
    ...device,
    viewport: { width: 844, height: 390 },
    screen: { width: 844, height: 390 },
  });
  const page = await context.newPage();
  await page.goto(targetUrl, { waitUntil: "domcontentloaded" });
  const result = await regression(page);
  const serialized = `${JSON.stringify(result, null, 2)}\n`;
  process.stdout.write(serialized);
  if (outputPath) await writeFile(resolve(outputPath), serialized, "utf8");
  await context.close();
} finally {
  await browser.close();
}
