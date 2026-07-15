import { test, expect } from '@playwright/test';
import { waitForPageReady } from './helpers';

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
