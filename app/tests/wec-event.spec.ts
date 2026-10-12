import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const TRACKER_COLUMN = '[data-tracker-column]';

/**
 * The tracker's column, which stands in the strip from page load. It arrives
 * on the first frame that knows the field, so it is the column that is waited
 * for.
 */
async function waitForTrackerColumn(page: Page) {
  await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
}

test.describe('Le Mans 2025 Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
  });

  // Mid-race state: the standings and their gaps, the cars on the tracker, and
  // the columns the page opens on, one for each class the field runs. The rendering
  // at lap 180 is determined solely by the lap data.
  test('should render a mid-race state correctly', async ({ page }) => {
    await setLapCount(page, 180);
    await expect(page.getByText('KUBICA').first()).toBeVisible();
    await expect(page).toHaveScreenshot('lap-180.png', {
      fullPage: true,
    });
  });

  // The tracker's column: the circuit at full detail, the sector boundaries drawn
  // across the line and the fifteen mini-sector names Le Mans is timed by.
  test('should render the tracker at full detail', async ({ page }) => {
    await setLapCount(page, 180);
    await waitForTrackerColumn(page);
    await expect(page.locator(TRACKER_COLUMN)).toHaveScreenshot('tracker-column-lap-180.png');
  });
});
