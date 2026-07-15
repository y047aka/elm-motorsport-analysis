import { test, expect } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

test.describe('Le Mans 2025 Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
  });

  // Mid-race state: verifies the standings gaps, car positions on the
  // tracker, and the populated SelectedCarsStrip. The rendering at lap 180
  // is determined solely by the lap data.
  test('should render a mid-race state correctly', async ({ page }) => {
    await setLapCount(page, 180);
    await expect(page.getByText('KUBICA').first()).toBeVisible();
    await expect(page).toHaveScreenshot('lap-180.png', {
      fullPage: true,
    });
  });
});
