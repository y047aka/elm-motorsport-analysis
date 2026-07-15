import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const POPOVER = '#car-detail-popover';

/**
 * Open the car detail popover by clicking a standings row.
 * Rows are located by driver name (the driver on duty at lap 180 is fixed).
 */
async function openPopoverFor(page: Page, driverName: string) {
  await page
    .locator('button[popovertarget="car-detail-popover"]')
    .filter({ hasText: driverName })
    .first()
    .click();
  await expect(page.locator(POPOVER)).toBeVisible();
}

/** Car selector chip (#<carNumber>) inside the popover */
function chip(page: Page, carNumber: string) {
  return page.locator(POPOVER).getByRole('button', { name: `#${carNumber}`, exact: true });
}

test.describe('Car Detail Popover Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
    await waitForPageReady(page, 'text=24 Hours of Le Mans');
    await setLapCount(page, 180);
    // KUBICA is driving #83 at lap 180
    await openPopoverFor(page, 'KUBICA');
  });

  test('should render a single selected car', async ({ page }) => {
    await expect(page.locator(POPOVER)).toHaveScreenshot('single-car.png');
  });

  test('should render three cars with the position progression chart', async ({ page }) => {
    await chip(page, '6').click();
    await chip(page, '8').click();
    await page.locator(POPOVER).getByRole('button', { name: 'Position progression' }).click();
    await expect(page.locator(POPOVER)).toHaveScreenshot('three-cars-position-tab.png');
  });

  test('should render a recovery hint when every car is deselected', async ({ page }) => {
    await chip(page, '83').click();
    await expect(page.locator(POPOVER)).toHaveScreenshot('empty-selection.png');
  });
});
