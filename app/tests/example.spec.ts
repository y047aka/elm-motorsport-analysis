import { test, expect } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/Playwright/);
});

test.describe('Top Page Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    // load: DOMContentLoadedとすべてのリソース読み込み完了を待機
    await page.goto('/', { waitUntil: 'load' });

    // メインコンテンツの表示を確認
    await page.locator('[data-theme="dark"]').waitFor({ state: 'visible' });

    // 最後のセクション（Formula E 2025）が表示されるまで待機
    // これによりページ全体のレンダリング完了を確認
    await page.locator('text=Formula E 2025').waitFor({ state: 'visible' });

    // フォントの読み込み完了を待機（ビジュアル比較の安定性向上）
    await page.evaluate(() => document.fonts.ready);
  });

  test('should render the main page correctly', async ({ page }) => {
    await expect(page).toHaveScreenshot('top-page.png', {
      fullPage: true,
    });
  });
});
