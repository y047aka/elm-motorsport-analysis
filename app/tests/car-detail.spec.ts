import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const DETAIL = '#car-detail';
const STANDINGS_POPOVER = '#standings-popover';

/**
 * Select a car by clicking a standings row. The row opens a popover of its own,
 * which is dismissed so that it does not cover the detail view.
 * Rows are located by driver name (the driver on duty at lap 180 is fixed).
 */
async function selectCar(page: Page, driverName: string) {
  await page
    .locator('button[popovertarget="standings-popover"]')
    .filter({ hasText: driverName })
    .first()
    .click();
  await page.locator(STANDINGS_POPOVER).evaluate((el: HTMLElement) => el.hidePopover());
  await expect(page.locator(DETAIL)).toBeVisible();
}

/** Car selector chip (#<carNumber>) inside the detail view */
function chip(page: Page, carNumber: string) {
  return page.locator(DETAIL).getByRole('button', { name: `#${carNumber}`, exact: true });
}

test.describe('Car Detail Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
    await setLapCount(page, 180);
    // KUBICA is driving #83 at lap 180
    await selectCar(page, 'KUBICA');
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
