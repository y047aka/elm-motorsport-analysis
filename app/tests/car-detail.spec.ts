import { test, expect, Locator, Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { waitForPageReady, setLapCount } from './helpers';

const DETAIL = '[data-car-detail]';
const CLASS_COLUMN = '[data-class-column]';

/**
 * Reads a constant out of the source that decides it, rather than repeating
 * it here. A pattern that misses throws while the spec loads, taking every
 * test down with a named error -- a constant that moved modules without its
 * pattern would otherwise become `NaN`, and surface as an expectation of
 * `NaNpx` three hundred lines later.
 */
function readConstant(name: string, source: string, pattern: RegExp): number {
  const value = Number(pattern.exec(source)?.[1]);
  if (!Number.isFinite(value)) {
    throw new Error(`${name} not found in its source -- did it move?`);
  }
  return value;
}

/** One column's width, and the pitch one column moves by. */
const columnsSource = readFileSync(new URL('../src/Page/Wec/Columns.elm', import.meta.url), 'utf8');
const COLUMN_WIDTH = readConstant('Columns.width', columnsSource, /\nwidth =\n\s+(\d+)/);
const GAP = readConstant('Columns.gap', columnsSource, /gap =\n\s+(\d+)/);
const PITCH = COLUMN_WIDTH + GAP;

/** The standings' width and its two bounds, and the width one arrow key
 * step is worth. */
const standingsSource = readFileSync(new URL('../src/View/LiveStandings.elm', import.meta.url), 'utf8');
const STANDINGS_WIDTH = readConstant('LiveStandings.width', standingsSource, /\nwidth =\n\s+(\d+)/);
const STANDINGS_MIN = readConstant('LiveStandings.minWidth', standingsSource, /\nminWidth =\n\s+(\d+)/);
const STANDINGS_MAX = readConstant('LiveStandings.maxWidth', standingsSource, /\nmaxWidth =\n\s+(\d+)/);
const eventSource = readFileSync(new URL('../src/Page/Wec/Event.elm', import.meta.url), 'utf8');
const RESIZE_STEP = readConstant('standingsFence.step', eventSource, /standingsFence =\n\s*\{[\s\S]*?step = (\d+)/);

/** The car's row in the live standings, which is where a car is picked. */
function standingsRow(page: Page, carNumber: string) {
  // Exact, or `Car #5` is also the row of `Car #50`. Exactness is also what
  // keeps this off the rows of a class's column, which name the class.
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
  await settleStrip(page);
}

/** The same, in this order, which is the order the columns come up in. */
async function selectCars(page: Page, carNumbers: string[]) {
  for (const carNumber of carNumbers) {
    await selectCar(page, carNumber);
  }
}

/**
 * Wait for the strip to stop gliding. A click scrolls its button into view, and
 * on macOS that scroll is smooth: a grip measured while the strip still moves is
 * pressed where it was, not where it is. Opening a column scrolls the strip to
 * it, so this is waited on after every pick.
 */
function settleStrip(page: Page) {
  return page.locator('#column-strip').evaluate(
    (el) =>
      new Promise<void>((resolve) => {
        let last = el.scrollLeft;
        const tick = () => {
          if (el.scrollLeft === last) {
            resolve();
          } else {
            last = el.scrollLeft;
            requestAnimationFrame(tick);
          }
        };
        requestAnimationFrame(tick);
      }),
  );
}

/**
 * The classes the round fields, in the order the running order puts them, with
 * the cars each has out and the car each is led by at lap 180 -- the moment the
 * suite drives -- and at the start, before a class has settled.
 */
const CLASSES = [
  { name: 'HYPERCAR', cars: 21, leader: '6', atStart: '5' },
  { name: 'LMP2', cars: 17, leader: '48', atStart: '29' },
  { name: 'LMGT3', cars: 24, leader: '92', atStart: '27' },
];

/** The three cars the columns below are stood up from: one from each class. */
const THREE_CARS = CLASSES.map((c) => c.leader);

/** A class's own column, which is what the strip opens with. */
function classColumn(page: Page, className: string) {
  return page.locator(`[data-class-column="${className}"]`);
}

/** The rows of a class's column, leader first. */
function classRows(page: Page, className: string) {
  return classColumn(page, className).locator('button[aria-pressed]');
}

/** A car's row in a class's own column, which names the class it is drawn in. */
function classRow(page: Page, carNumber: string, className: string) {
  return page.getByRole('button', { name: `Car #${carNumber} in ${className}` });
}

/** Every column of the strip, left to right: a class's named, a car's numbered,
 * the tracker's as `TRACKER`. A class's column carries its class on the card it
 * is; a car's panel carries its number deeper in, and the tracker's column
 * carries neither. */
function stripOrder(page: Page) {
  return page.locator('#column-strip > div').evaluateAll((cells) =>
    cells.map(
      (cell) =>
        cell.querySelector('[data-class-column]')?.getAttribute('data-class-column') ??
        cell.querySelector('[data-car-detail]')?.getAttribute('data-car-detail') ??
        'TRACKER',
    ),
  );
}

/** The strip, holding what a test says it holds. */
async function expectStrip(page: Page, columns: string[]) {
  await expect.poll(() => stripOrder(page)).toEqual(columns);
}

/** What each row reports as the interval to the class-mate ahead of it. The
 * reading is drawn after the interval, and the car at the head of its class is
 * ahead of nobody, so reports nothing. */
function intervals(rows: Locator) {
  return rows.evaluateAll((els) =>
    els.map(
      (el) =>
        el.innerText
          .split('\n')
          .find((line) => line.startsWith('+') || line === '-') ?? '',
    ),
  );
}

/** Where a class's column rules itself into groups, in the words the rules are
 * labelled with. The rules are the list's only children that are not rows, and
 * the words are read as Elm wrote them rather than as CSS spells them. */
function divisions(page: Page, className: string) {
  return classColumn(page, className).evaluate((column) =>
    [...column.querySelectorAll('.overflow-y-auto > div')].map(
      (rule) => rule.textContent?.trim() ?? '',
    ),
  );
}

/** Whether a column stands whole inside the strip's own box. */
async function inView(page: Page, column: Locator) {
  const strip = (await page.locator('#column-strip').boundingBox())!;
  const box = (await column.boundingBox())!;
  return box.x >= strip.x - 1 && box.x + box.width <= strip.x + strip.width + 1;
}

/** Take the class columns out of the strip, and wait for it to stop gliding. */
async function closeClassColumns(page: Page) {
  for (const class_ of CLASSES) {
    const standing = await page.locator(CLASS_COLUMN).count();
    if (standing === 0) break;
    await page
      .locator(CLASS_COLUMN)
      .first()
      .getByRole('button', { name: 'Close this column' })
      .click();
    await expect(page.locator(CLASS_COLUMN)).toHaveCount(standing - 1);
  }
  await settleStrip(page);
}

/**
 * Stand three cars up in columns of their own, then take the class columns out
 * of the strip: what the tests below drive is a strip of car columns, and with
 * the class's columns closed the places a test counts are the places the strip
 * holds.
 */
async function standCars(page: Page) {
  await selectCars(page, THREE_CARS);
  await closeClassColumns(page);
  await expectStrip(page, THREE_CARS);
  await stripToHead(page);
}

/**
 * A column for this car and no other, the class's columns included: a panel is
 * drawn with a close button of its own only once the strip holds more than the
 * column it stands in, and the baseline was rendered with one column there.
 */
async function selectOnlyCar(page: Page, carNumber: string) {
  await selectCar(page, carNumber);
  await closeClassColumns(page);
  const others = () => page.locator(`${DETAIL}:not([data-car-detail="${carNumber}"])`);
  for (let left = await others().count(); left > 0; left -= 1) {
    await others().first().getByRole('button', { name: 'Close this column' }).click();
    await expect(others()).toHaveCount(left - 1);
  }
}

/** Take the strip back to its own head, and wait for it to stop gliding: opening
 * a column scrolls the strip to it, and a press at the coordinates of a column
 * scrolled off the edge lands on whatever is drawn there. */
async function stripToHead(page: Page) {
  await page.locator('#column-strip').evaluate((el) => {
    el.scrollLeft = 0;
  });
  await settleStrip(page);
}

/** The grip of whichever column stands at `index` in the strip, class's, car's or
 * the tracker's. */
function stripGrip(page: Page, index: number) {
  return page
    .locator('#column-strip > div')
    .nth(index)
    .getByRole('button', { name: 'Move this column' });
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
    // A local run only: at 328x162 the config's 0.001 is 53 pixels, and the
    // macOS rendering of these lines differs from CI's by 55. CI stays at 0.
    await expect(section(page, 'Comparison')).toHaveScreenshot(
      'position-tab.png',
      process.env.CI ? {} : { maxDiffPixelRatio: 0.0015 },
    );
  });

  test('should draw the car\'s own curve over its rivals\' in the distribution', async ({ page }) => {
    await page.locator(DETAIL).getByRole('button', { name: 'Lap time' }).click();
    await expect(section(page, 'Comparison')).toHaveScreenshot('distribution-tab.png');
  });

  test('should hold the panel sections in their order', async ({ page }) => {
    const sections = await page.locator(DETAIL).locator('h3').allTextContents();
    expect(sections.map((s) => s.replace(/[^A-Za-z ]/g, '').trim()))
      .toEqual(['Rivals', 'Lap times', 'Comparison', 'Stints', 'Log']);
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
 * The class's own column: what the strip opens with, one per class, which is how
 * a field of several classes reads while the race is still sorting itself out --
 * every car of a class at once, each against the class-mate ahead of it.
 */
test.describe('Class columns', () => {
  test.beforeEach(async ({ page }) => {
    await openEvent(page);
  });

  test('should open the strip with a column for each class the field runs', async ({ page }) => {
    // A race is several races, and the front of each is a fight rather than a
    // car, so the page follows the classes until the reader says otherwise -- in
    // the order the running order puts the classes in.
    await expectStrip(page, CLASSES.map((c) => c.name));
    // A column as any other is: named in the header's list of them, and the
    // reader's to close.
    for (const class_ of CLASSES) {
      await expect(
        page.getByRole('button', { name: `Scroll to the ${class_.name} column` }),
      ).toBeVisible();
    }
    await expect(page.getByRole('button', { name: 'Close this column' })).toHaveCount(
      CLASSES.length,
    );
    // Nothing has been picked, so no car is marked anywhere.
    await expect(page.locator('[data-live-standings] [aria-pressed="true"]')).toHaveCount(0);
  });

  test('should list every car the class has out, leader first', async ({ page }) => {
    // The whole class in one column, which is the one thing a column per car
    // cannot do: a class running its stops early is visible here at once.
    for (const class_ of CLASSES) {
      await expect(classRows(page, class_.name)).toHaveCount(class_.cars);
      await expect(classColumn(page, class_.name)).toContainText(`${class_.cars} cars`);
    }
    // The class place leads the row, ahead of the number and the surname: a car
    // is 1st here and 22nd on the standings beside it, and both are true.
    const rows = await classRows(page, 'HYPERCAR').evaluateAll((els) =>
      els.slice(0, 6).map((el) => el.innerText.split('\n').slice(0, 3).join(' ')),
    );
    expect(rows).toEqual([
      '1 6 VANTHOOR',
      '2 83 KUBICA',
      '3 8 HARTLEY',
      '4 51 GIOVINAZZI',
      '5 50 FUOCO',
      '6 15 MARCIELLO',
    ]);
  });

  test('should read every car against the class-mate ahead of it', async ({ page }) => {
    // The intervals down the whole of Hypercar, leader first. The Hypercar on a
    // lap with an LMP2 car is timed with it, and this chain is not that reading:
    // each row is measured to the row above it, and to nothing else.
    expect(await intervals(classRows(page, 'HYPERCAR'))).toEqual([
      '',
      '+ 14.766',
      '+ 58.731',
      '+ 49.971',
      '+ 20.176',
      '+ 1.550',
      '+ 28.370',
      '+ 11.515',
      '+ 11.979',
      '+ 3.539',
      '-',
      '+ 46.909',
      '+ 41.044',
      '+ 0.881',
      '+ 5.511',
      '+ 1:22.626',
      '+ 8.000',
      '+ 1:15.711',
      '+ 1:56.717',
      '+ 3 Laps',
      '+ 1:43.682',
    ]);
    // The head of the class is ahead of nobody, and a car in the pit lane has no
    // interval to be had: row 1 is drawn without a reading and #7 with a dash.
    // A car a lap down its class-mate reads in laps, not in seconds.
  });

  test('should hold each class to a reference of its own', async ({ page }) => {
    // The fastest lap the class has run and the number of the car that ran it --
    // not the race's fastest, which a faster class ran: an LMGT3 car nobody
    // would call quick is race leader among its own.
    await expect(classColumn(page, 'HYPERCAR')).toContainText('3:27.534');
    await expect(classColumn(page, 'HYPERCAR')).toContainText('#38');
    await expect(classColumn(page, 'LMGT3')).toContainText('3:56.169');
    await expect(classColumn(page, 'LMGT3')).toContainText('#87');
    // The two references are the classes' own, and so are two different laps.
    expect(await classColumn(page, 'HYPERCAR').innerText()).not.toContain('3:56.169');
  });

  test('should go on following the class as the race runs', async ({ page }) => {
    // Nothing picked, nothing moved: the column is the class's running order,
    // which is the race's to change. Before the first lap is done the classes are
    // led by other cars, and no class has finished a timed lap to be a reference.
    await setLapCount(page, 0);
    for (const class_ of CLASSES) {
      await expect(classRows(page, class_.name).first()).toContainText(class_.atStart);
      await expect(classColumn(page, class_.name)).toContainText('no timed lap');
    }
    await setLapCount(page, 180);
    for (const class_ of CLASSES) {
      await expect(classRows(page, class_.name).first()).toContainText(class_.leader);
      await expect(classColumn(page, class_.name)).not.toContainText('no timed lap');
    }
  });

  test('should open a car of the class in a column of its own', async ({ page }) => {
    await classRow(page, '83', 'HYPERCAR').click();
    // The class is followed still, and one of its cars is followed in detail
    // beside it.
    await expectColumns(page, ['83']);
    await expectStrip(page, [...CLASSES.map((c) => c.name), '83']);
    await expect(standingsRow(page, '83')).toHaveAttribute('aria-pressed', 'true');
    // The new column stood off the strip's own right edge, and the strip went to
    // it: a press whose result the reader cannot see reads as a press that did
    // nothing.
    await expect.poll(() => inView(page, page.locator(DETAIL))).toBe(true);
    // Its row is drawn marked, and pressing a marked row goes to the column that
    // is standing rather than opening a second one of the same car.
    await expect(classRow(page, '83', 'HYPERCAR')).toHaveAttribute('aria-pressed', 'true');
    await classRow(page, '83', 'HYPERCAR').click();
    await expectColumns(page, ['83']);
    await expect.poll(() => inView(page, page.locator(DETAIL))).toBe(true);
    // An unmarked row is a pick, and marks itself.
    await classRow(page, '8', 'HYPERCAR').click();
    await expectColumns(page, ['83', '8']);
    await expect(classRow(page, '8', 'HYPERCAR')).toHaveAttribute('aria-pressed', 'true');
  });

  test('should keep the rest of the class columns when one is closed', async ({ page }) => {
    await classColumn(page, 'HYPERCAR')
      .getByRole('button', { name: 'Close this column' })
      .click();
    await expectStrip(page, ['LMP2', 'LMGT3']);
    // The page stops choosing for the reader: still following, it would have
    // filled Hypercar's place back in from the class it leads on the next render.
    await selectCar(page, '83');
    await expectStrip(page, ['LMP2', 'LMGT3', '83']);
  });

  test('should call a closed class column back by its name', async ({ page }) => {
    await classColumn(page, 'HYPERCAR')
      .getByRole('button', { name: 'Close this column' })
      .click();
    await expectStrip(page, ['LMP2', 'LMGT3']);
    // The class's name in the standings is where its column is asked for again,
    // which is where the class's cars are listed already.
    await page.getByRole('button', { name: 'Open the HYPERCAR column' }).click();
    await expectStrip(page, ['LMP2', 'LMGT3', 'HYPERCAR']);
    await expect(page.getByRole('button', { name: 'Open the HYPERCAR column' })).toHaveCount(0);
    // A class with a column is drawn as a name, not as a thing to open.
    await expect(classColumn(page, 'HYPERCAR')).toBeVisible();
  });

  test('should say which cars are in the pit lane', async ({ page }) => {
    const pits = await classRows(page, 'HYPERCAR').evaluateAll((els) =>
      els
        .filter((el) => /\bPIT\b|\bOUT\b/.test(el.innerText))
        .map((el) => el.getAttribute('aria-label')),
    );
    expect(pits).toEqual([
      'Car #50 in HYPERCAR',
      'Car #7 in HYPERCAR',
      'Car #38 in HYPERCAR',
      'Car #35 in HYPERCAR',
      'Car #311 in HYPERCAR',
    ]);
  });

  test('should rule the class where it splits, and name the cars that stopped', async ({ page }) => {
    // A class is not one field. The cars on the leader's lap are racing it, the
    // ones below are a lap further back, and the ones that stopped are classified
    // rather than distanced -- which is what the rules between the rows say, in
    // the words a gap of laps is read in.
    expect(await divisions(page, 'HYPERCAR')).toEqual([
      '1 Lap down',
      '2 Laps down',
      '5 Laps down',
      '6 Laps down',
    ]);
    expect(await divisions(page, 'LMGT3')).toEqual([
      '1 Lap down',
      '2 Laps down',
      '3 Laps down',
      '4 Laps down',
      'Retired',
    ]);
    // Nothing is measured between a car that stopped and one that did not, so the
    // three rows below the last rule report no interval at all: the rule carries
    // that, and says so once.
    expect((await intervals(classRows(page, 'LMGT3'))).slice(-3)).toEqual(['', '', '']);
  });

  test('should read a class column whole at the width a car is drawn at', async ({ page }) => {
    // One line to a car, in the cell a car's panel is drawn in: the readings are
    // all there, so the name is the only thing that could give -- and none of
    // them do, for any car of any class.
    const cut = await page.evaluate(() =>
      [...document.querySelectorAll('[data-class-column] button[aria-pressed]')]
        .map((row) => {
          const name = [...row.querySelectorAll('div')].find((cell) =>
            (cell as HTMLElement).className.includes('truncate'),
          ) as HTMLElement;
          return name && name.scrollWidth > name.clientWidth
            ? `${row.getAttribute('aria-label')}: ${name.textContent}`
            : null;
        })
        .filter(Boolean),
    );
    expect(cut).toEqual([]);
    // The same cell as a car's column, so one pitch moves the strip whichever
    // kind of column stands in it.
    await expect(page.locator('#column-strip > div').nth(0)).toHaveCSS('width', `${COLUMN_WIDTH}px`);
    await expect(page.locator('#column-strip > div').nth(2)).toHaveCSS('width', `${COLUMN_WIDTH}px`);
    await selectCar(page, '83');
    await expect(page.locator('#column-strip > div').nth(CLASSES.length)).toHaveCSS(
      'width',
      `${COLUMN_WIDTH}px`,
    );
    await settleStrip(page);
    expect(await page.locator('#column-strip').evaluate((el) => el.scrollLeft)).toBeGreaterThan(0);
  });

  test('should move a class column by the keys, and say which class moved', async ({ page }) => {
    // The class is what the strip opens with, and a class is moved as a car is.
    await stripGrip(page, 0).focus();
    await page.keyboard.press('ArrowRight');
    await expectStrip(page, ['LMP2', 'HYPERCAR', 'LMGT3']);
    await expect(stripGrip(page, 1)).toBeFocused();
    await expect(page.locator('[aria-live="polite"]')).toHaveText(
      'HYPERCAR column moved to column 2 of 3',
    );
  });

  test('should not move the page when a car of the class is picked', async ({ page }) => {
    // The class's tile in the header's list stands as tall as the car badge's
    // does: were it a slimmer thing, the first pick of a race -- which is what
    // this page is opened for -- would push the whole page down.
    const height = () =>
      page.locator('#column-strip').evaluate((el) => el.getBoundingClientRect().height);
    const before = await height();
    await selectCar(page, '83');
    await expect.poll(() => height()).toBe(before);
  });
});

/**
 * As many columns as the reader asks for, each drawn against the rivals of the
 * car it holds.
 */
test.describe('Car Detail Columns', () => {
  /**
   * The strip cell a column's content is drawn in -- the only ancestors
   * that hold a column's width and placement. One reading of what a cell
   * is, so a change to how the strip draws one lands in a single place.
   */
  function cellOf(content: Locator) {
    return content.locator('xpath=ancestor::*[contains(@class, "shrink-0")][1]');
  }

  /** The column a panel is drawn in, which is what carries its width. */
  function column(page: Page, index: number) {
    return cellOf(page.locator(DETAIL).nth(index));
  }

  /** The grip a column is carried by. */
  function grip(page: Page, index: number) {
    return page.locator(DETAIL).nth(index).getByRole('button', { name: 'Move this column' });
  }

  /** The grip of whichever column stands at `index` in the strip. */
  function stripGrip(page: Page, index: number) {
    return page
      .locator('#column-strip > div')
      .nth(index)
      .getByRole('button', { name: 'Move this column' });
  }

  /**
   * Press on a column's grip and carry it `by` pixels sideways, without letting
   * go. The moves wait for the grip to say it is held: until Elm has drawn it
   * so, it is not listening for them.
   */
  async function carry(page: Page, index: number, by: number) {
    const handle = grip(page, index);
    const box = (await handle.boundingBox())!;
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await expect(handle).toHaveClass(/cursor-grabbing/);
    await page.mouse.move(x + by, y, { steps: 10 });
  }

  test.beforeEach(async ({ page }) => {
    await openEvent(page);
    await standCars(page);
  });

  test('should let a pick join the columns of the strip rather than replace them', async ({ page }) => {
    // A press that unmarked their rows would be the one press on the
    // standings that takes columns away.
    await selectCar(page, '83');
    await expectColumns(page, [...THREE_CARS, '83']);
    for (const carNumber of THREE_CARS) {
      await expect(standingsRow(page, carNumber)).toHaveAttribute('aria-pressed', 'true');
    }
  });

  test('should keep the columns in the order they were opened', async ({ page }) => {
    // The running order has #83 ahead of #12, so this order is one it could
    // not have produced.
    await selectCar(page, '12');
    await selectCar(page, '83');
    await expectColumns(page, [...THREE_CARS, '12', '83']);
  });

  test('should hold every column to a width its panel stays readable at', async ({ page }) => {
    // Every car's column is as wide as its panel needs, however many are up. The
    // class's column is narrower, which is the class's own test.
    for (let i = 0; i < THREE_CARS.length; i++) {
      await expect(column(page, i)).toHaveCSS('width', `${COLUMN_WIDTH}px`);
    }
    await selectCar(page, '83');
    await expect(column(page, THREE_CARS.length)).toHaveCSS('width', `${COLUMN_WIDTH}px`);
  });

  /** The standings' own card, which carries its width itself. */
  function standingsCell(page: Page) {
    return page.locator('[data-live-standings]');
  }

  /** The grip along the standings' right edge that resizes them. */
  function standingsGrip(page: Page) {
    return page.getByRole('button', { name: 'Resize the standings column' });
  }

  /**
   * Press the standings' resize grip and carry it `by` pixels sideways,
   * without letting go -- the same wait as a column carry: the grip only
   * listens for moves once Elm has drawn it held.
   */
  async function resizeStandings(page: Page, by: number) {
    const handle = standingsGrip(page);
    const box = (await handle.boundingBox())!;
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await expect(handle).toHaveClass(/cursor-grabbing/);
    await page.mouse.move(x + by, y, { steps: 10 });
  }

  test('should resize the standings by its grip, held to its bounds', async ({ page }) => {
    const standings = standingsCell(page);
    await expect(standings).toHaveCSS('width', `${STANDINGS_WIDTH}px`);
    await resizeStandings(page, -(STANDINGS_WIDTH - STANDINGS_MIN) / 2);
    await expect(standings).toHaveCSS('width', `${(STANDINGS_WIDTH + STANDINGS_MIN) / 2}px`);
    // Past the narrowest there is: the width stops where `minWidth` says.
    await page.mouse.move(-200, 300, { steps: 5 });
    await expect(standings).toHaveCSS('width', `${STANDINGS_MIN}px`);
    await page.mouse.up();
    await expect(standings).toHaveCSS('width', `${STANDINGS_MIN}px`);
    // And back: the drag starts from the width the grip found.
    await resizeStandings(page, STANDINGS_MAX - STANDINGS_MIN);
    await expect(standings).toHaveCSS('width', `${STANDINGS_MAX}px`);
    await page.mouse.up();
    await expect(standings).toHaveCSS('width', `${STANDINGS_MAX}px`);
  });

  test('should step the standings width by the arrow keys', async ({ page }) => {
    const standings = standingsCell(page);
    await standingsGrip(page).focus();
    await page.keyboard.press('ArrowLeft');
    await expect(standings).toHaveCSS('width', `${STANDINGS_WIDTH - RESIZE_STEP}px`);
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('ArrowRight');
    await expect(standings).toHaveCSS('width', `${STANDINGS_WIDTH + RESIZE_STEP}px`);
  });

  test('should leave the last column off the edge, reachable by scrolling', async ({ page }) => {
    // Three stood up and three picked, which is past what the cell holds
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
    // column-wide header -- rather than one panel on its own.
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
    await expect(page.getByRole('button', { name: 'Move this column' })).toHaveCount(0);
  });

  test('should move a column to the place nearest where it is let go of', async ({ page }) => {
    // Most of the way past two columns, which rounds to two.
    await carry(page, 0, PITCH * 1.6);
    await page.mouse.up();
    await expectColumns(page, ['48', '92', '6']);
  });

  test('should draw a carried column under the pointer and leave the rest in place until it is let go of', async ({ page }) => {
    await carry(page, 0, PITCH);
    // Nothing is reordered while the grip holds the pointer: the column it
    // has passed is drawn a place back instead.
    await expectColumns(page, THREE_CARS);
    await expect(column(page, 0)).toHaveCSS('transform', `matrix(1, 0, 0, 1, ${PITCH}, 0)`);
    await expect(column(page, 1)).toHaveCSS('transform', `matrix(1, 0, 0, 1, ${-PITCH}, 0)`);
    await expect(column(page, 2)).toHaveCSS('transform', 'matrix(1, 0, 0, 1, 0, 0)');
    await page.mouse.up();
    await expectColumns(page, ['48', '6', '92']);
    for (let i = 0; i < 3; i++) {
      await expect(column(page, i)).toHaveCSS('transform', 'none');
    }
  });

  test('should hold a carried column to the strip', async ({ page }) => {
    await carry(page, 1, -PITCH * 3);
    // Three places left is past the strip's head: the carry is held one
    // pitch back, to the strip's own left edge.
    await expect(column(page, 1)).toHaveCSS('transform', `matrix(1, 0, 0, 1, ${-PITCH}, 0)`);
    await page.mouse.up();
    await expectColumns(page, ['48', '6', '92']);
  });

  /**
   * How far down each column is scrolled, left to right. The box a column
   * scrolls in holds everything but the header, so it sits inside the detail
   * element rather than around it, and is named by the car number the detail
   * element carries.
   */
  function columnScrolls(page: Page) {
    return page
      .locator(DETAIL)
      .evaluateAll((els) =>
        els.map((el) => document.getElementById(`column-scroll-${el.getAttribute('data-car-detail')}`)!.scrollTop),
      );
  }

  /**
   * Scroll each column down by its own amount, so that none reads as another.
   * Elm hears of a scroll by its event, which the next frame delivers: a key
   * pressed before then reorders columns it has not heard were scrolled.
   */
  async function scrollColumns(page: Page, tops: number[]) {
    await page.locator(DETAIL).evaluateAll(async (els, tops) => {
      els.forEach((el, i) => {
        document.getElementById(`column-scroll-${el.getAttribute('data-car-detail')}`)!.scrollTop = tops[i];
      });
      await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
    }, tops);
    await expect.poll(() => columnScrolls(page)).toEqual(tops);
  }

  test('should keep how far down each column was scrolled when one is carried past another', async ({ page }) => {
    // Short enough that every panel scrolls.
    await page.setViewportSize({ width: 1440, height: 600 });
    // The first column's grip stays in sight to be pressed.
    await scrollColumns(page, [0, 40, 80]);
    await carry(page, 0, PITCH);
    await page.mouse.up();
    await expectColumns(page, ['48', '6', '92']);
    await expect.poll(() => columnScrolls(page)).toEqual([40, 0, 80]);
  });

  test('should keep how far down each column was scrolled when one is stepped past another', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 600 });
    await grip(page, 0).focus();
    await scrollColumns(page, [20, 40, 80]);
    await page.keyboard.press('ArrowRight');
    await expectColumns(page, ['48', '6', '92']);
    await expect(grip(page, 1)).toBeFocused();
    await expect.poll(() => columnScrolls(page)).toEqual([40, 20, 80]);
  });

  test('should count the strip scrolled under a carried column as carrying it', async ({ page }) => {
    for (const carNumber of ['83', '12', '8']) {
      await selectCar(page, carNumber);
    }
    await stripToHead(page);
    await carry(page, 0, 0);
    // The strip is read where the carry began a frame after the grip is held.
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    await column(page, 0).locator('xpath=..').evaluate(
      (strip, pitch) => {
        strip.scrollLeft += pitch * 2;
      },
      PITCH,
    );
    // Still under the pointer, which has not moved.
    await expect(column(page, 0)).toHaveCSS('transform', `matrix(1, 0, 0, 1, ${PITCH * 2}, 0)`);
    await page.mouse.up();
    await expectColumns(page, ['48', '92', '6', '83', '12', '8']);
  });

  test('should stop following the running order once a column has been moved', async ({ page }) => {
    await carry(page, 0, PITCH);
    await page.mouse.up();
    await expectColumns(page, ['48', '6', '92']);
    await setLapCount(page, 0);
    await expectColumns(page, ['48', '6', '92']);
  });

  test('should not step a column by the keys while one is being carried', async ({ page }) => {
    // The press has focused the grip, so the keys reach it.
    await carry(page, 0, PITCH);
    await expect(grip(page, 0)).toBeFocused();
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('ArrowRight');
    await expectColumns(page, THREE_CARS);
    await expect(grip(page, 0)).toHaveClass(/cursor-grabbing/);
    await page.mouse.up();
    await expectColumns(page, ['48', '6', '92']);
  });

  test('should keep a carry to the pointer that picked it up', async ({ page }) => {
    // Two fingers, one on each of two grips. Dispatched rather than driven: the
    // mouse Playwright drives is one pointer.
    const touch = (index: number, type: string, pointerId: number, x: number) =>
      grip(page, index).evaluate(
        (el, init) => el.dispatchEvent(new PointerEvent(init.type, { ...init, bubbles: true, button: 0, pointerType: 'touch' })),
        { type, pointerId, clientX: x },
      );
    await touch(0, 'pointerdown', 2, 100);
    await expect(grip(page, 0)).toHaveClass(/cursor-grabbing/);
    // The second finger's press and release are its own, and move nothing.
    await touch(1, 'pointerdown', 3, 100);
    await touch(1, 'pointerup', 3, 100 + PITCH * 2);
    await touch(1, 'lostpointercapture', 3, 100 + PITCH * 2);
    await expectColumns(page, THREE_CARS);
    await expect(grip(page, 0)).toHaveClass(/cursor-grabbing/);
    await touch(0, 'pointerup', 2, 100 + PITCH);
    await expectColumns(page, ['48', '6', '92']);
  });

  test('should end a carry whose column is closed under it, and leave it closed', async ({ page }) => {
    await carry(page, 0, 0);
    // The grip has the focus, and the close button is the next thing along.
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await expectColumns(page, ['48', '92']);
    // Let go of over the grip that has taken the closed one's place.
    await page.mouse.up();
    await expectColumns(page, ['48', '92']);
    await grip(page, 0).focus();
    await page.keyboard.press('ArrowRight');
    await expectColumns(page, ['92', '48']);
  });

  test('should end a carry whose grip goes when the other columns are closed', async ({ page }) => {
    await page.locator(DETAIL).nth(2).getByRole('button', { name: 'Close this column' }).click();
    // The close was the strip's own scroll: the grips are gliding until it
    // stops, and the carry below presses at measured coordinates.
    await settleStrip(page);
    await carry(page, 0, PITCH);
    // A second finger, closing the other column: the mouse is held by the grip.
    await page.locator(DETAIL).nth(1).getByRole('button', { name: 'Close this column' }).evaluate((el) => (el as HTMLElement).click());
    await expectColumns(page, ['6']);
    // The last column closed its grip with it, and letting go of what is
    // left puts the strip back as it stood.
    await expect(column(page, 0)).toHaveCSS('transform', 'none');
    await page.mouse.up();
    await selectCar(page, '83');
    await carry(page, 0, PITCH);
    await page.mouse.up();
    await expectColumns(page, ['83', '6']);
  });

  test('should move a column a place at a time by the arrow keys, and keep its grip focused', async ({ page }) => {
    await expect(grip(page, 0)).toHaveAttribute('aria-keyshortcuts', 'ArrowLeft ArrowRight');
    await grip(page, 0).focus();
    await page.keyboard.press('ArrowRight');
    await expectColumns(page, ['48', '6', '92']);
    await expect(grip(page, 1)).toBeFocused();
    // Said, for a reader who cannot see where it went.
    await expect(page.locator('[aria-live="polite"]')).toHaveText('Car #6 moved to column 2 of 3');
    await page.keyboard.press('ArrowRight');
    // Past the end, where there is nowhere further to go.
    await page.keyboard.press('ArrowRight');
    await expectColumns(page, ['48', '92', '6']);
    await expect(grip(page, 2)).toBeFocused();
    await page.keyboard.press('ArrowLeft');
    await expectColumns(page, ['48', '6', '92']);
  });

  test('should take a column for every car asked for, with no ceiling', async ({ page }) => {
    // Eight, past what the cell holds at any viewport -- it scrolls to the
    // rest.
    const asked = ['12', '8', '7', '83', '51', '50', '36', '35'];
    for (const carNumber of asked) {
      await selectCar(page, carNumber);
    }
    await expectColumns(page, [...THREE_CARS, ...asked]);
    await expect(standingsRow(page, '35')).toHaveAttribute('aria-pressed', 'true');
  });
});
