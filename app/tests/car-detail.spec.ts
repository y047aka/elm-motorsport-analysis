import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const DETAIL = '#car-detail';

/** The car's row in the live standings, which is where a car is picked. */
function standingsRow(page: Page, carNumber: string) {
  return page.getByRole('button', { name: `Car #${carNumber}` });
}

/** Select a car by its row in the live standings. */
async function selectCar(page: Page, carNumber: string) {
  await standingsRow(page, carNumber).click();
  await expect(page.locator(DETAIL)).toBeVisible();
}

test.describe('Car Detail Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
    await setLapCount(page, 180);
    await selectCar(page, '83');
  });

  test('should render the selected car with its rivals ahead and behind', async ({ page }) => {
    await expect(page.locator(DETAIL)).toHaveScreenshot('selected-car-with-rivals.png');
  });

  test('should render the position progression chart', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Position progression' }).click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('position-tab.png');
  });

  test('should render the car\'s own laps as a table', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Laps', exact: true }).click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('laps-tab.png');
  });

  test('should render a recovery hint when the car is deselected', async ({ page }) => {
    await standingsRow(page, '83').click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('empty-selection.png');
  });
});
