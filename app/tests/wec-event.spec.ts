import { test, expect } from '@playwright/test';
import { waitForPageReady, setLapCount, expectSurveyedLap, TRACKER_COLUMN, LE_MANS } from './helpers';

test.describe('Le Mans 2025 Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
  });

  // Mid-race state: the standings and their gaps, the cars on the tracker, and
  // the columns the page opens on -- one per class the field runs, the tracker
  // behind them. The rendering at lap 180 is determined solely by the lap data.
  test('should render a mid-race state correctly', async ({ page }) => {
    await setLapCount(page, LE_MANS, 180);
    await expect(page.getByText('KUBICA').first()).toBeVisible();
    await expect(page).toHaveScreenshot('lap-180.png', {
      fullPage: true,
    });
  });

  // The tracker drew the surveyed lap and not the ring it falls back to --
  // asserted without a baseline, as the circuit's own drawing is held to its
  // bytes by the geometry project's fences rather than by pixels.
  test('should draw the surveyed lap and not the ring', async ({ page }) => {
    await setLapCount(page, LE_MANS, 180);
    await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
    await expectSurveyedLap(page);
  });
});
