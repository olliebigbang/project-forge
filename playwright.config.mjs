import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  forbidOnly: Boolean(process.env.CI),
  timeout: 90_000,
  expect: {
    timeout: 15_000,
  },
  outputDir: "output/playwright/test-results",
  reporter: [
    ["line"],
    ["html", { outputFolder: "output/playwright/html-report", open: "never" }],
  ],
  use: {
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    trace: "retain-on-failure",
    video: "off",
  },
  projects: [
    {
      name: "mobile-chromium",
      use: {
        ...devices["iPhone 15"],
        viewport: { width: 844, height: 390 },
        screen: { width: 844, height: 390 },
      },
    },
  ],
});
