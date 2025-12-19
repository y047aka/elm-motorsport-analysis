import { test, expect } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/Playwright/);
});

test.describe('Top Page Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    // Wait for the main content to be visible
    await page.locator('[data-theme="dark"]').waitFor({ state: 'visible' });
    await page.waitForTimeout(1000);
  });

  test('should render the main page correctly', async ({ page }) => {
    await expect(page).toHaveScreenshot('top-page.png', {
      fullPage: true,
    });
  });
});
