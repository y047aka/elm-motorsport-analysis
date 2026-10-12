import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const TRACKER_PANE = '[data-tracker-pane]';
const TRACKER_COLUMN = '[data-tracker-column]';

/**
 * Open a column of the tracker. The pane's card is the opener, and the column
 * arrives on the next frame, so it is the column that is waited for.
 */
async function openTrackerColumn(page: Page) {
  await page.locator(TRACKER_PANE).click();
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
    await openTrackerColumn(page);
    await expect(page.locator(TRACKER_COLUMN)).toHaveScreenshot('tracker-column-lap-180.png');
  });

  // The tracker's pane: the same circuit at the detail the page opens with, which
  // is drawn at a scale where a tenth of a metre of the survey is a larger part of
  // the shot than of any other.
  test('should render the tracker in its pane', async ({ page }) => {
    await setLapCount(page, 180);
    await expect(page.locator(TRACKER_PANE)).toHaveScreenshot('tracker-pane-lap-180.png');
  });
});
