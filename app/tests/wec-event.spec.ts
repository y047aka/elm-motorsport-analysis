import { test, expect } from '@playwright/test';
import { waitForPageReady, setLapCount, expectSurveyedLap, TRACKER_COLUMN, LE_MANS } from './helpers';

const FLOAT_CARD = '[data-tracker-float-card]';

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

  // The circuit raised off the ground it was surveyed on, at the pose it opens at:
  // the band, the pit lane riding on it, the sector lines, and the field drawn as
  // the discs the cars stand on. Nothing turns it here -- the pose is the one the
  // model opens at -- so the pixels follow the lap data alone.
  test('should render the raised circuit floated over the columns', async ({ page }) => {
    await setLapCount(page, LE_MANS, 180);
    await page
      .locator(TRACKER_COLUMN)
      .getByRole('button', { name: 'Float the track map over the columns' })
      .click();
    await expect(page.locator(FLOAT_CARD)).toHaveCount(1);

    // The box drew the circuit and not the ring, apart from the pixels: a round
    // exported before the summary named its circuit raises a ring into space, and a
    // raised ring still looks like a track.
    await expectSurveyedLap(page, FLOAT_CARD);

    // The chrome is the pointer's, and the pointer is still where the `◱` was pressed: the
    // shot is the box at rest, with no navigation over the map.
    await page.mouse.move(0, 0);

    await expect(page.locator(FLOAT_CARD)).toHaveScreenshot('tracker-3d-float.png');
  });
});
