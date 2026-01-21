import { test, expect, Page } from '@playwright/test';

const WAIT_TIMEOUT = 5000;

/**
 * ページのレンダリング完了を待機するヘルパー関数
 * @param page Playwrightのページオブジェクト
 * @param contentSelector ページ固有のコンテンツを示すセレクター
 */
async function waitForPageReady(page: Page, contentSelector: string) {
  await page.locator('[data-theme="dark"]').waitFor({ state: 'visible', timeout: WAIT_TIMEOUT });
  await page.locator(contentSelector).waitFor({ state: 'visible', timeout: WAIT_TIMEOUT });
  await page.evaluate(() => document.fonts.ready);
}

test.describe('Top Page Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=Formula E 2025');
  });

  test('should render the main page correctly', async ({ page }) => {
    await expect(page).toHaveScreenshot('top-page.png', {
      fullPage: true,
    });
  });
});

test.describe('Le Mans 2025 Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
  });

  test('should render Le Mans 2025 page correctly', async ({ page }) => {
    await expect(page).toHaveScreenshot('le-mans-2025.png', {
      fullPage: true,
    });
  });
});
