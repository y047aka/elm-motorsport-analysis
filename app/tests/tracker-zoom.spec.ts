import { test, expect, Locator, Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { waitForPageReady, setLapCount, TRACKER_COLUMN, COTA } from './helpers';

/**
 * The tracker taking a row of its own below the columns is two rows the page is
 * laid out in rather than a thing drawn, so nothing here is pixels: what is
 * asserted is which row each of the two stands in, how the split between them
 * moves, and how big the circuit's own polygon ended up. The row the enlarged
 * tracker keeps and the bounds it can be taken between are read out of the Elm
 * that decides them, so a number moved there moves the expectation with it.
 */
const eventSource = readFileSync(new URL('../src/Page/Wec/Event.elm', import.meta.url), 'utf8');

/** As `car-detail.spec.ts`'s own `readConstant`: a pattern that misses takes the
 * spec load down by name rather than letting the constant become `NaN`. */
function readConstant(name: string, pattern: RegExp): number {
  const value = Number(pattern.exec(eventSource)?.[1]);
  if (!Number.isFinite(value)) {
    throw new Error(`${name} not found in Page/Wec/Event.elm -- did it move?`);
  }
  return value;
}

const TRACKER_ROW = readConstant('defaultTrackerRow', /\ndefaultTrackerRow =\n\s+(\d+)/);
const ROW_MIN = readConstant('trackerRowFence.min', /\ntrackerRowFence =\n\s*\{\s*min = (\d+)/);
const ROW_MAX = readConstant('trackerRowFence.max', /trackerRowFence =\n\s*\{[^}]*max = (\d+)/);
const ROW_STEP = readConstant('trackerRowFence.step', /trackerRowFence =\n\s*\{[^}]*step = (\d+)/);

const TOGGLE = '[data-tracker-toggle]';
const EXPANDED = '[data-tracker-expanded]';
const STRIP = '#column-strip';

/** The cell the enlarged tracker stands in, whose height is the row the grip
 * sets -- the card inside it is shorter by its own padding. */
const ROW = '[data-tracker-row]';

/** The column's own toggle: the enlarged drawing carries a second one. */
const toggleTracker = (page: Page) => page.locator(`${TRACKER_COLUMN} ${TOGGLE}`);

/** The grip along the row edge between the two rows, which only the enlarged
 * page has. */
const rowGrip = (page: Page): Locator =>
  page.getByRole('button', { name: 'Resize the enlarged tracker' });

/** The circuit as it comes out on screen -- the polygon, not the box it is
 * centred in, which is the full width of its card whatever the circuit's shape. */
function drawn(page: Page, selector: string) {
  return page.locator(`${selector} svg polygon`).boundingBox();
}

/**
 * Press the row grip and carry it `by` pixels down, without letting go -- the
 * same wait a column carry and the standings' resize use: the grip only listens
 * for moves once Elm has drawn it held. A travel down is the strip's gain and
 * the tracker row's loss, the way a boundary between two things works.
 */
async function resizeRows(page: Page, by: number) {
  const handle = rowGrip(page);
  const box = (await handle.boundingBox())!;
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await expect(handle).toHaveClass(/cursor-grabbing/);
  await page.mouse.move(x, y + by, { steps: 10 });
}

test.describe('the enlarged tracker', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`/wec/${COTA}`, { waitUntil: 'load' });
    await waitForPageReady(page, 'text=Lone Star Le Mans');
    await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
    await setLapCount(page, COTA, 71);
  });

  test('draws the circuit in a row of its own, leaving the strip the larger share', async ({ page }) => {
    const before = (await page.locator(STRIP).boundingBox())!;
    const inColumn = (await drawn(page, TRACKER_COLUMN))!;

    await toggleTracker(page).click();
    await expect(page.locator(EXPANDED)).toHaveCount(1);

    const strip = (await page.locator(STRIP).boundingBox())!;
    const row = (await page.locator(ROW).boundingBox())!;
    const onScreen = (await drawn(page, EXPANDED))!;

    // The tracker keeps its own row at the bottom of the page, and the strip
    // keeps the top and what is left of it -- more than the map was given.
    expect(row.y).toBeGreaterThanOrEqual(strip.y + strip.height - 1);
    expect(row.y + row.height).toBeLessThanOrEqual(before.y + before.height + 1);
    expect(row.height).toBeCloseTo(TRACKER_ROW, 0);
    expect(strip.height).toBeGreaterThan(row.height);

    // The same track, bigger than the one still standing in the column.
    expect(onScreen.width).toBeGreaterThan(inColumn.width);
    expect(onScreen.height).toBeGreaterThan(inColumn.height);
  });

  test('gives the room back when pressed again, by a mark that says so', async ({ page }) => {
    const before = (await page.locator(STRIP).boundingBox())!;

    await toggleTracker(page).click();
    await expect(page.locator(EXPANDED)).toHaveCount(1);

    // What opened the enlargement is not what closes it: both corners take the
    // ⤢ for a ✕ once the enlarged tracker is up.
    await expect(page.locator(`${EXPANDED} ${TOGGLE}`)).toHaveAttribute('aria-label', 'Close the enlarged tracker');
    await expect(toggleTracker(page)).toHaveAttribute('aria-label', 'Close the enlarged tracker');
    await page.getByRole('button', { name: 'Close the enlarged tracker' }).first().click();
    await expect(page.locator(EXPANDED)).toHaveCount(0);

    const after = (await page.locator(STRIP).boundingBox())!;
    expect(after.y).toBeCloseTo(before.y, 0);
    expect(after.height).toBeCloseTo(before.height, 0);
  });

  test('carries the split between the two rows by the grip along their edge', async ({ page }) => {
    const row = page.locator(ROW);
    await toggleTracker(page).click();
    await expect(rowGrip(page)).toHaveCount(1);
    await expect(row).toHaveCSS('height', `${TRACKER_ROW}px`);

    // Down: the columns gain and the map loses, the boundary moving with the
    // pointer wherever the size is held.
    await resizeRows(page, 100);
    await expect(row).toHaveCSS('height', `${TRACKER_ROW - 100}px`);

    // Past the shortest there is: the row stops where the fence says.
    await page.mouse.move(700, 3000, { steps: 5 });
    await expect(row).toHaveCSS('height', `${ROW_MIN}px`);
    await page.mouse.up();
    await expect(row).toHaveCSS('height', `${ROW_MIN}px`);

    // And back: the carry starts from the row the grip found, not the default.
    await resizeRows(page, -(ROW_MAX - ROW_MIN + 50));
    await expect(row).toHaveCSS('height', `${ROW_MAX}px`);
    await page.mouse.up();
    await expect(row).toHaveCSS('height', `${ROW_MAX}px`);
  });

  test('steps the split by the arrow keys the grip answers to', async ({ page }) => {
    const row = page.locator(ROW);
    await toggleTracker(page).click();

    await rowGrip(page).focus();
    await page.keyboard.press('ArrowDown');
    await expect(row).toHaveCSS('height', `${TRACKER_ROW - ROW_STEP}px`);
    await page.keyboard.press('ArrowUp');
    await page.keyboard.press('ArrowUp');
    await expect(row).toHaveCSS('height', `${TRACKER_ROW + ROW_STEP}px`);

    // The sideways keys are another grip's business, and step nothing here.
    await page.keyboard.press('ArrowRight');
    await expect(row).toHaveCSS('height', `${TRACKER_ROW + ROW_STEP}px`);
  });
});
