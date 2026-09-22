import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  snapshotPathTemplate: '{testDir}/{testFileDir}/{testFileName}-snapshots/{arg}{ext}',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['github'], ['html']] : 'html',

  use: {
    baseURL: 'http://localhost:1234',
    trace: 'on-first-retry',
    launchOptions: {
      // Playwright already launches Chromium with `--no-sandbox`, unless
      // `chromiumSandbox: true` asks it not to.
      args: ['--font-render-hinting=none', '--disable-lcd-text'],
    },
  },

  expect: {
    toHaveScreenshot: {
      // Greyscale antialiasing, so a local run compares against CI's Linux
      // baselines with room to spare. See tests/screenshot.css.
      //
      // The room a shot needs grows with how much text and how many chart
      // strokes it holds: the panel on its own sat under 0.0003, two panels
      // side by side wanted 0.0004 and the standings 0.00032.
      stylePath: './tests/screenshot.css',
      ...(process.env.CI
        ? { maxDiffPixels: 0 }
        : { maxDiffPixelRatio: 0.001 }),
    },
  },

  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium', viewport: { width: 1440, height: 900 } },
    },
  ],

  webServer: {
    command: 'pnpm start',
    port: 1234,
    timeout: 120000,
    reuseExistingServer: !process.env.CI,
  }
});
