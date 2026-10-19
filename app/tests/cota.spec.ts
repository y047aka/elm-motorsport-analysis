import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount, expectSurveyedLap, TRACKER_COLUMN, COTA } from './helpers';

/**
 * The tracker's column stands in the strip from page load, empty until the first
 * frame that knows the field.
 */
async function waitForTrackerColumn(page: Page) {
  await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
}

test.describe('Circuit of the Americas Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/cota_6h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=Lone Star Le Mans');
  });

  test('should draw the surveyed lap and not the ring', async ({ page }) => {
    await setLapCount(page, COTA, 71);
    await waitForTrackerColumn(page);
    await expectSurveyedLap(page);
  });

  // The lap, the pit lane beside it and the three sector boundaries the round is
  // timed at, at the lengths COTA's `Layout` writes for itself.
  //
  // Lap 71 is where the field is widest: 35 of the 36 cars are out, running over 18
  // of the 20 tenths of the lap, at a green-flag stretch between the safety car at
  // 2:50 and the next at 4:03.
  test('should render the tracker at full detail', async ({ page }) => {
    await setLapCount(page, COTA, 71);
    await waitForTrackerColumn(page);
    await expect(page.locator(TRACKER_COLUMN)).toHaveScreenshot('tracker-column-lap-71.png');
  });
});
