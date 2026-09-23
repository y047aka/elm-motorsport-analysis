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

/** The stand-in columns the page opens on, before anything has been picked. */
const STAND_INS = ['6', '48', '92'];

/**
 * A column for this car and no other. A pick joins the columns already up, so
 * the three the page stands in with have to be closed to be rid of them.
 */
async function selectOnlyCar(page: Page, carNumber: string) {
  await selectCar(page, carNumber);
  const others = () => page.locator(`${DETAIL}:not([data-car-detail="${carNumber}"])`);
  for (let left = await others().count(); left > 0; left -= 1) {
    await others().first().getByRole('button', { name: 'Close this column' }).click();
    await expect(others()).toHaveCount(left - 1);
  }
}

/** One section of a panel, found by its heading. */
function section(page: Page, heading: string) {
  return page.locator(DETAIL).locator(`xpath=.//h3[normalize-space()="${heading}"]/..`);
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
    // One panel: these locate by `DETAIL` alone, which is a strict-mode
    // violation the moment there are two.
    await selectOnlyCar(page, '83');
  });

  test('should render the selected car with its rivals ahead and behind', async ({ page }) => {
    await expect(page.locator(DETAIL)).toHaveScreenshot('selected-car-with-rivals.png');
  });

  test('should render the position progression chart', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Positions' }).click();
    await expect(section(page, 'Comparison')).toHaveScreenshot('position-tab.png');
  });

  test('should draw the car\'s own curve over its rivals\' in the distribution', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Distribution' }).click();
    await expect(section(page, 'Comparison')).toHaveScreenshot('distribution-tab.png');
  });

  test('should open the car\'s own laps at the end of the panel', async ({ page }) => {
    const history = page.locator(DETAIL).locator('details');
    await expect(history).not.toHaveAttribute('open');
    await history.locator('summary', { hasText: 'Lap history' }).click();
    await expect(history).toHaveAttribute('open', '');
    // Last, so that four hundred rows push nothing a reader came for off the
    // bottom of the panel. The rivals lead, being where the header's standing
    // line stops.
    const sections = await page.locator(DETAIL).locator('h3, summary').allTextContents();
    expect(sections.map((s) => s.replace(/[^A-Za-z ]/g, '').trim()))
      .toEqual(['Rivals', 'Lap times', 'Comparison', 'Stints', 'Lap history']);
    await expect(history).toHaveScreenshot('lap-history.png');
  });

  test('should keep the car it was given when its own row is clicked again', async ({ page }) => {
    // Forced: the row is marked and carries no handler, and what is being
    // tested is the press rather than whether it is offered.
    await standingsRow(page, '83').click({ force: true });
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
    // #6 leads the class and so is measured against nothing; each row below
    // carries its own gap to the row above. The place leads the row.
    expect(read).toEqual([
      ['6', '1st', '-'],
      ['83', '2nd', '+ 14.766'],
      ['8', '3rd', '+ 58.731'],
    ]);
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

  test('should show the leader of each class when no car has been picked', async ({ page }) => {
    // Each class's own leader, in the order the running order puts the classes
    // in -- which is the order their leaders are in. The race is several races,
    // and the car leading the field is leading one of them.
    await expectColumns(page, ['6', '48', '92']);
    // Drawn as any column is: a mark on the row says the car has one, which is
    // as true of a stand-in as of a pick, and each is the reader's to close.
    await expect(page.getByRole('button', { name: 'Close this column' })).toHaveCount(3);
    const marked = await page
      .locator('[data-live-standings] [aria-pressed="true"]')
      .evaluateAll((els) => els.map((el) => el.getAttribute('aria-label')));
    expect(marked).toEqual(['Car #6', 'Car #48', 'Car #92']);
    // Each of the three leads the class its panel reports, and a car does not
    // lead itself by nought: the reading against the class leader is no
    // reading at all.
    const toLeader = await page.locator(DETAIL).evaluateAll((panels) =>
      panels.map((panel) => {
        const label = [...panel.querySelectorAll('div')].find(
          (el) => el.textContent === 'Class leader',
        );
        return label?.nextElementSibling?.textContent?.trim() ?? null;
      }),
    );
    expect(toLeader).toEqual(['-', '-', '-']);
  });

  test('should not press a row whose car is already standing in', async ({ page }) => {
    // #6 is already drawn, standing in for Hypercar, so its row is marked
    // and carries no handler -- the same as any car with a column.
    await standingsRow(page, '6').click({ force: true });
    await expectColumns(page, ['6', '48', '92']);
  });

  test('should keep the rest of the stand-ins when one of them is closed', async ({ page }) => {
    // The page stops choosing once one is gone. Still following, it would
    // have filled #48's place back in from the class it leads on the next
    // render.
    await page.locator(DETAIL).nth(1).getByRole('button', { name: 'Close this column' }).click();
    await expectColumns(page, ['6', '92']);
    await expect(standingsRow(page, '48')).toHaveAttribute('aria-pressed', 'false');
  });

  test('should let a pick join the stand-ins rather than replace them', async ({ page }) => {
    // A press that unmarked their rows would be the one press on the
    // standings that takes columns away.
    await selectCar(page, '83');
    await expectColumns(page, [...STAND_INS, '83']);
    for (const carNumber of STAND_INS) {
      await expect(standingsRow(page, carNumber)).toHaveAttribute('aria-pressed', 'true');
    }
  });

  test('should keep the columns in the order they were opened', async ({ page }) => {
    // The running order has #83 ahead of #12, so this order is one it could
    // not have produced.
    await selectCar(page, '12');
    await selectCar(page, '83');
    await expectColumns(page, [...STAND_INS, '12', '83']);
  });

  test('should hold every column to a width its panel stays readable at', async ({ page }) => {
    // Before a car has been picked at all: the class leaders stand in, each in
    // a column rather than handed the cell.
    await expect(column(page, 0)).toHaveCSS('width', '360px');
    await selectOnlyCar(page, '83');
    await expect(column(page, 0)).toHaveCSS('width', '360px');
    await selectCar(page, '12');
    for (let i = 0; i < 2; i++) {
      await expect(column(page, i)).toHaveCSS('width', '360px');
    }
  });

  test('should leave the third column off the edge, reachable by scrolling', async ({ page }) => {
    // Three stood in with and three picked, which is past what the cell holds
    // at any viewport the suite runs at.
    for (const carNumber of ['83', '12', '8']) {
      await selectCar(page, carNumber);
    }
    await expect(page.locator(DETAIL)).toHaveCount(6);
    const columns = column(page, 0).locator('xpath=..');
    const { clientWidth, scrollWidth } = await columns.evaluate((el) => ({
      clientWidth: el.clientWidth,
      scrollWidth: el.scrollWidth,
    }));
    expect(scrollWidth).toBeGreaterThan(clientWidth);
  });

  test('should draw the columns side by side, each with its own close button', async ({ page }) => {
    await selectOnlyCar(page, '83');
    await selectCar(page, '12');
    await expectColumns(page, ['83', '12']);
    // The strip the columns sit in, so that what is recorded is the pair
    // together -- their width, the gap, and where the close button lands in a
    // header 360px wide -- rather than one panel on its own.
    await expect(column(page, 0).locator('xpath=..')).toHaveScreenshot('columns-side-by-side.png');
  });

  test('should show the same chart in every column, whichever one picks it', async ({ page }) => {
    await selectOnlyCar(page, '83');
    await selectCar(page, '12');
    await page.locator(DETAIL).nth(1).getByRole('button', { name: 'Positions' }).click();
    for (let i = 0; i < 2; i++) {
      // Asked of the button rather than of its classes: the greys it is
      // drawn in name the pressed one and the hover of the rest alike.
      await expect(page.locator(DETAIL).nth(i).getByRole('button', { name: 'Positions' }))
        .toHaveAttribute('aria-pressed', 'true');
    }
  });

  test('should close a column from the column itself', async ({ page }) => {
    await selectOnlyCar(page, '83');
    await selectCar(page, '12');
    await page.locator(DETAIL).nth(0).getByRole('button', { name: 'Close this column' }).click();
    await expectColumns(page, ['12']);
    // The standings stop saying the closed car is up, and will take it again.
    await expect(standingsRow(page, '83')).toHaveAttribute('aria-pressed', 'false');
  });

  test('should not offer to close the only column there is', async ({ page }) => {
    await selectOnlyCar(page, '83');
    await expectColumns(page, ['83']);
    await expect(page.getByRole('button', { name: 'Close this column' })).toHaveCount(0);
  });

  test('should take a column for every car asked for, with no ceiling', async ({ page }) => {
    // Eight, past what the cell holds at any viewport -- it scrolls to the
    // rest.
    const asked = ['12', '8', '7', '83', '51', '50', '36', '35'];
    for (const carNumber of asked) {
      await selectCar(page, carNumber);
    }
    await expectColumns(page, [...STAND_INS, ...asked]);
    await expect(standingsRow(page, '35')).toHaveAttribute('aria-pressed', 'true');
  });
});
