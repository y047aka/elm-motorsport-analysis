import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount, expectSurveyedLap, TRACKER_COLUMN, COTA } from './helpers';

/**
 * The tracker's column stands in the strip from page load, empty until the first
 * frame that knows the field, and falls back to the ring without failing when
 * the drawing is gone. What holds the drawing is not pixels: the bytes it is
 * made of are reproduced from the kept Overpass answer by the byte fence, held
 * to the word the app reaches for by `geometry-contract.spec.ts`, and laid
 * against the drawing's lengths by `Circuit/Layout`'s ratios. What is checked
 * here is the one thing only the browser can say: that a round open at a lap
 * drew the surveyed lap rather than the ring. Lap 71 is where the field is
 * widest — 35 of the 36 cars out, running over 18 of the 20 tenths of the lap.
 */
async function waitForTrackerColumn(page: Page) {
  await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
}

test.describe('Circuit of the Americas', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/cota_6h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=Lone Star Le Mans');
  });

  test('should draw the surveyed lap and not the ring', async ({ page }) => {
    await setLapCount(page, COTA, 71);
    await waitForTrackerColumn(page);
    await expectSurveyedLap(page);
  });
});
