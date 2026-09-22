import { test, expect, Page } from '@playwright/test';
import { waitForPageReady, setLapCount } from './helpers';

const DETAIL = '[data-car-detail]';

/** The car's row in the live standings, which is where a car is picked. */
function standingsRow(page: Page, carNumber: string) {
  // Exact, or `Car #5` is also the row of `Car #50`.
  return page.getByRole('button', { name: `Car #${carNumber}`, exact: true });
}

async function openEvent(page: Page) {
  await page.goto('/wec/2025/le_mans_24h', { waitUntil: 'load' });
  await waitForPageReady(page, 'text=24 Hours of Le Mans');
  await setLapCount(page, 180);
}

/**
 * Give a car a column of its own, by its row in the live standings. The row is
 * waited on rather than the columns: there can be several of those, and the row
 * says on itself once the car it names is up.
 */
async function selectCar(page: Page, carNumber: string) {
  await standingsRow(page, carNumber).click();
  await expect(standingsRow(page, carNumber)).toHaveAttribute('aria-pressed', 'true');
}

/**
 * The cars the columns are drawn for, left to right. Polled: Elm renders on the
 * next frame, so a press has not reached the page by the time it returns.
 */
function expectColumns(page: Page, carNumbers: string[]) {
  return expect
    .poll(() =>
      page
        .locator(DETAIL)
        .evaluateAll((els) => els.map((el) => el.getAttribute('data-car-detail'))),
    )
    .toEqual(carNumbers);
}

test.describe('Car Detail Visual Tests', () => {
  test.beforeEach(async ({ page }) => {
    await openEvent(page);
    await selectCar(page, '83');
  });

  test('should render the selected car with its rivals ahead and behind', async ({ page }) => {
    await expect(page.locator(DETAIL)).toHaveScreenshot('selected-car-with-rivals.png');
  });

  test('should render the position progression chart', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Positions' }).click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('position-tab.png');
  });

  test('should draw the car\'s own curve over its rivals\' in the distribution', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Distribution' }).click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('distribution-tab.png');
  });

  test('should render the car\'s own laps under its lap times', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Lap history' }).click();
    await expect(page.locator(DETAIL)).toHaveScreenshot('lap-history.png');
  });

  test('should keep the car it was given when its own row is clicked again', async ({ page }) => {
    await standingsRow(page, '83').click();
    await expect(standingsRow(page, '83')).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator(DETAIL)).toHaveCount(1);
    await expect(page.locator(DETAIL)).toContainText('AF Corse');
  });

  test('should lead the race when no car has been picked', async ({ page }) => {
    await openEvent(page);
    await expect(page.locator(DETAIL)).toHaveScreenshot('leader-by-default.png');
  });
});

/**
 * As many columns as the reader asks for, each drawn against the rivals of the
 * car it holds, up to a ceiling of six.
 */
test.describe('Car Detail Columns', () => {
  /** The column a panel is drawn in, which is what carries its width. */
  function column(page: Page, index: number) {
    return page.locator(DETAIL).nth(index).locator('xpath=ancestor::*[contains(@class, "shrink-0")][1]');
  }

  test.beforeEach(async ({ page }) => {
    await openEvent(page);
  });

  test('should give a picked car a column without taking the last one away', async ({ page }) => {
    await selectCar(page, '83');
    await selectCar(page, '12');
    await expectColumns(page, ['83', '12']);
  });

  test('should keep the columns in the order they were opened', async ({ page }) => {
    // The reverse of the pair above. The running order holds these two one way
    // round, so one of the two orders is one it could not have produced.
    await selectCar(page, '12');
    await selectCar(page, '83');
    await expectColumns(page, ['12', '83']);
  });

  test('should hold every column to a width its panel stays readable at', async ({ page }) => {
    await selectCar(page, '83');
    await selectCar(page, '12');
    for (let i = 0; i < 2; i++) {
      await expect(column(page, i)).toHaveCSS('width', '440px');
    }
  });

  test('should leave the third column off the edge, reachable by scrolling', async ({ page }) => {
    for (const carNumber of ['83', '12', '8']) {
      await selectCar(page, carNumber);
    }
    await expect(page.locator(DETAIL)).toHaveCount(3);
    const columns = column(page, 0).locator('xpath=..');
    const { clientWidth, scrollWidth } = await columns.evaluate((el) => ({
      clientWidth: el.clientWidth,
      scrollWidth: el.scrollWidth,
    }));
    expect(scrollWidth).toBeGreaterThan(clientWidth);
  });

  test('should draw the columns side by side, each with its own close button', async ({ page }) => {
    await selectCar(page, '83');
    await selectCar(page, '12');
    await expectColumns(page, ['83', '12']);
    // The strip the columns sit in, so that what is recorded is the pair
    // together -- their width, the gap, and where the close button lands in a
    // header 440px wide -- rather than one panel on its own.
    await expect(column(page, 0).locator('xpath=..')).toHaveScreenshot('columns-side-by-side.png');
  });

  test('should dim the rows it will not take once six columns are up', async ({ page }) => {
    for (const carNumber of ['12', '8', '7', '83', '51', '50']) {
      await selectCar(page, carNumber);
    }
    await expectColumns(page, ['12', '8', '7', '83', '51', '50']);
    await expect(page.locator('.col-start-1')).toHaveScreenshot('standings-at-the-limit.png');
  });

  test('should show the same chart in every column, whichever one picks it', async ({ page }) => {
    await selectCar(page, '83');
    await selectCar(page, '12');
    await page.locator(DETAIL).nth(1).getByRole('button', { name: 'Positions' }).click();
    for (let i = 0; i < 2; i++) {
      await expect(page.locator(DETAIL).nth(i).getByRole('button', { name: 'Positions' }))
        .toHaveClass(/bg-primary/);
    }
  });

  test('should close a column from the column itself', async ({ page }) => {
    await selectCar(page, '83');
    await selectCar(page, '12');
    await page.locator(DETAIL).nth(0).getByRole('button', { name: 'Close this column' }).click();
    await expectColumns(page, ['12']);
    // The standings stop saying the closed car is up, and will take it again.
    await expect(standingsRow(page, '83')).toHaveAttribute('aria-pressed', 'false');
  });

  test('should not offer to close the only column there is', async ({ page }) => {
    await selectCar(page, '83');
    await expect(page.getByRole('button', { name: 'Close this column' })).toHaveCount(0);
  });

  test('should stop at six columns, and say so on the rows it will not take', async ({ page }) => {
    for (const carNumber of ['12', '8', '7', '83', '51', '50']) {
      await selectCar(page, carNumber);
    }
    await expectColumns(page, ['12', '8', '7', '83', '51', '50']);

    const seventh = standingsRow(page, '36');
    await expect(seventh).toHaveAttribute('aria-disabled', 'true');
    // Forced, because Playwright will not click a row it can see is disabled.
    // What is being checked is the row underneath that: it carries no handler,
    // so a press that does get through still opens nothing.
    await seventh.click({ force: true });
    await expectColumns(page, ['12', '8', '7', '83', '51', '50']);
  });
});
