import { defineConfig, devices } from '@playwright/test';

/**
 * See https://playwright.dev/docs/test-configuration.
 */
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
      args: [
        '--font-render-hinting=none',
        '--disable-lcd-text',
        ...(process.env.CI ? ['--no-sandbox'] : []),
      ],
    },
  },

  expect: {
    timeout: 5000,
    toHaveScreenshot: {
      // Greyscale antialiasing, so a local run compares against CI's Linux
      // baselines with room to spare. See tests/screenshot.css.
      stylePath: './tests/screenshot.css',
      ...(process.env.CI
        ? { maxDiffPixels: 0 }
        : { maxDiffPixelRatio: 0.0003 }),
    },
  },

  projects: [
    {
      name: 'Google Chrome',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 900 }
      },
    },
  ],

  webServer: {
    command: 'pnpm start',
    port: 1234,
    timeout: 120000,
    reuseExistingServer: !process.env.CI,
  }
});
