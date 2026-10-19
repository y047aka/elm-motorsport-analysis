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

  // Which of the two drawings a round is put in is the summary's `track.circuit`,
  // so a summary exported before that key existed draws this lap as the ring it
  // falls back to. The ring is a circle the cars run round and the surveyed lap is
  // a polygon, which is told apart here without a baseline to compare pixels to.
  test('should draw the surveyed lap and not the ring', async ({ page }) => {
    await setLapCount(page, COTA, 71);
    await waitForTrackerColumn(page);
    await expectSurveyedLap(page);
  });

  // The lap, the pit lane beside it and the three sector boundaries the round is
  // timed at, at the lengths COTA writes for itself: three tenths of the metres Le
  // Mans's tracker is measured in, which is a scale rather than a measurement -- a
  // lap 1,825 m across and 1,043 m tall is wide-to-tall 1.75 where Le Mans is 0.50,
  // so no one multiplier is right in both directions of that.
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
