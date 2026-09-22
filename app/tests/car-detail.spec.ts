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

  test('should open the car\'s own laps at the end of the panel', async ({ page }) => {
    const history = page.locator(DETAIL).getByRole('button', { name: 'Lap history' });
    await expect(history).toHaveAttribute('aria-expanded', 'false');
    await history.click();
    // Last, so that four hundred rows push nothing a reader came for off the
    // bottom of the panel. The rivals lead, being where the header's standing
    // line stops.
    const sections = await page.locator(DETAIL).locator('h3, [aria-expanded]').allTextContents();
    expect(sections.map((s) => s.replace(/[^A-Za-z ]/g, '').trim()))
      .toEqual(['Rivals', 'Lap times', 'Comparison', 'Stints', 'Lap history']);
    await expect(page.locator(DETAIL)).toHaveScreenshot('lap-history.png');
  });

  test('should keep the car it was given when its own row is clicked again', async ({ page }) => {
    await standingsRow(page, '83').click();
    await expect(standingsRow(page, '83')).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator(DETAIL)).toHaveCount(1);
    await expect(page.locator(DETAIL)).toContainText('AF Corse');
  });

  test('should read the legend down the order, not out from the picked car', async ({ page }) => {
    const rows = page.locator(DETAIL).locator('[data-rival]');
    await expect(rows).toHaveCount(3);
    const read = await rows.evaluateAll((els) =>
      els.map((el) => [
        el.getAttribute('data-rival'),
        el.firstElementChild!.textContent!.trim(),
        el.lastElementChild!.textContent!.trim(),
      ]),
    );
    // #6 leads the class and so is measured against nothing. The picked car
    // carries its own gap to it, where that figure used to sit on #6's row
    // with the sign the other way round. The place leads the row.
    expect(read).toEqual([
      ['6', 'P1', '-'],
      ['83', 'P2', '+ 14.766'],
      ['8', 'P3', '+ 58.731'],
    ]);
  });

  test('should lead the race when no car has been picked', async ({ page }) => {
    await openEvent(page);
    await expect(page.locator(DETAIL)).toHaveScreenshot('leader-by-default.png');
  });
});

/**
 * As many columns as the reader asks for, each drawn against the rivals of the
 * car it holds.
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
    // Before a car has been picked at all: the leader stands in, and stands in
    // a column rather than being handed the cell whole.
    await expect(column(page, 0)).toHaveCSS('width', '440px');
    await selectCar(page, '83');
    await expect(column(page, 0)).toHaveCSS('width', '440px');
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

  test('should take a column for every car asked for, with no ceiling', async ({ page }) => {
    // Eight, which is past the six the page used to stop at and past what the
    // cell holds either way -- it scrolls to the rest.
    const asked = ['12', '8', '7', '83', '51', '50', '36', '35'];
    for (const carNumber of asked) {
      await selectCar(page, carNumber);
    }
    await expectColumns(page, asked);
    await expect(standingsRow(page, '35')).toHaveAttribute('aria-pressed', 'true');
  });
});
