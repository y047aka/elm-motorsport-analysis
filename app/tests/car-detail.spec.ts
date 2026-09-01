import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const DETAIL = '#car-detail';

/** Car selector chip (#<carNumber>) inside the detail view */
function chip(page: Page, carNumber: string) {
  return page.locator(DETAIL).getByRole('button', { name: `#${carNumber}`, exact: true });
}

/** Select a car by its chip in the detail view. */
async function selectCar(page: Page, carNumber: string) {
  await chip(page, carNumber).click();
  await expect(page.locator(DETAIL)).toBeVisible();
}

test.describe('Car Detail Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
    await setLapCount(page, 180);
    await selectCar(page, '83');
  });

  test('should render a single selected car', async ({ page }) => {
    await expect(page.locator(DETAIL)).toHaveScreenshot('single-car.png');
  });

  test('should render three cars with the position progression chart', async ({ page }) => {
    await chip(page, '6').click();
    await chip(page, '8').click();
    await page.locator(DETAIL).getByRole('button', { name: 'Position progression' }).click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('three-cars-position-tab.png');
  });

  test('should render a recovery hint when every car is deselected', async ({ page }) => {
    await chip(page, '83').click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('empty-selection.png');
  });
});
