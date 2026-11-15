import { test, expect, Locator, Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { waitForPageReady, setLapCount, TRACKER_COLUMN, COTA } from './helpers';

/**
 * The tracker taking the room below the columns is two rows the page is laid
 * out in rather than a thing drawn, so nothing here is pixels: what is asserted
 * is which row each of the two stands in, how the split between them moves, and
 * how big the circuit's own polygon ended up. The row the strip keeps and the
 * bounds it can be taken between are read out of the Elm that decides them, so a
 * number moved there moves the expectation with it.
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

const STRIP_ROW = readConstant('stripRow', /\nstripRow =\n\s+(\d+)/);
const ROW_MIN = readConstant('rowsFence.min', /\nrowsFence =\n\s*\{\s*min = (\d+)/);
const ROW_MAX = readConstant('rowsFence.max', /rowsFence =\n\s*\{[^}]*max = (\d+)/);
const ROW_STEP = readConstant('rowsFence.step', /rowsFence =\n\s*\{[^}]*step = (\d+)/);

const ZOOM = '[data-tracker-zoom]';
const EXPANDED = '[data-tracker-expanded]';
const STRIP = '#column-strip';

/** The column's own toggle: the enlarged drawing carries a second one. */
const zoomIn = (page: Page) => page.locator(`${TRACKER_COLUMN} ${ZOOM}`);

/** The grip along the row edge between the two rows, which only the enlarged
 * page has. */
const rowGrip = (page: Page): Locator =>
  page.getByRole('button', { name: "Resize the columns' row" });

/** The circuit as it comes out on screen -- the polygon, not the box it is
 * centred in, which is the full width of its card whatever the circuit's shape. */
function drawn(page: Page, selector: string) {
  return page.locator(`${selector} svg polygon`).boundingBox();
}

/**
 * Press the row grip and carry it `by` pixels down, without letting go -- the
 * same wait a column carry and the standings' resize use: the grip only listens
 * for moves once Elm has drawn it held.
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

  test('draws the circuit in the room below the strip', async ({ page }) => {
    const before = (await page.locator(STRIP).boundingBox())!;
    const inColumn = (await drawn(page, TRACKER_COLUMN))!;

    await zoomIn(page).click();
    await expect(page.locator(EXPANDED)).toHaveCount(1);

    const strip = (await page.locator(STRIP).boundingBox())!;
    const enlarged = (await page.locator(EXPANDED).boundingBox())!;
    const onScreen = (await drawn(page, EXPANDED))!;

    // The strip keeps the top of the page and its own row; the tracker takes
    // what is left of the page under it.
    expect(strip.y).toBeCloseTo(before.y, 0);
    expect(strip.height).toBeCloseTo(STRIP_ROW, 0);
    expect(enlarged.y).toBeGreaterThanOrEqual(strip.y + strip.height - 1);
    expect(enlarged.y + enlarged.height).toBeLessThanOrEqual(before.y + before.height + 1);

    // The same track, bigger than the one still standing in the column.
    expect(onScreen.width).toBeGreaterThan(inColumn.width);
    expect(onScreen.height).toBeGreaterThan(inColumn.height);
  });

  test('gives the room back when pressed again', async ({ page }) => {
    const before = (await page.locator(STRIP).boundingBox())!;

    await zoomIn(page).click();
    await expect(page.locator(EXPANDED)).toHaveCount(1);
    await zoomIn(page).click();
    await expect(page.locator(EXPANDED)).toHaveCount(0);

    const after = (await page.locator(STRIP).boundingBox())!;
    expect(after.y).toBeCloseTo(before.y, 0);
    expect(after.height).toBeCloseTo(before.height, 0);
  });

  test('carries the split between the two rows by the grip along their edge', async ({ page }) => {
    await zoomIn(page).click();
    await expect(rowGrip(page)).toHaveCount(1);
    await expect(page.locator(STRIP)).toHaveCSS('height', `${STRIP_ROW}px`);

    // Down, so the strip's row grows and the tracker's shrinks.
    await resizeRows(page, 100);
    await expect(page.locator(STRIP)).toHaveCSS('height', `${STRIP_ROW + 100}px`);

    // Past the shortest there is: the row stops where the fence says.
    await page.mouse.move(700, -1000, { steps: 5 });
    await expect(page.locator(STRIP)).toHaveCSS('height', `${ROW_MIN}px`);
    await page.mouse.up();
    await expect(page.locator(STRIP)).toHaveCSS('height', `${ROW_MIN}px`);

    // And back: the carry starts from the row the grip found, not the default.
    await resizeRows(page, ROW_MAX - ROW_MIN + 50);
    await expect(page.locator(STRIP)).toHaveCSS('height', `${ROW_MAX}px`);
    await page.mouse.up();
    await expect(page.locator(STRIP)).toHaveCSS('height', `${ROW_MAX}px`);
  });

  test('steps the split by the arrow keys the grip answers to', async ({ page }) => {
    await zoomIn(page).click();

    await rowGrip(page).focus();
    await page.keyboard.press('ArrowDown');
    await expect(page.locator(STRIP)).toHaveCSS('height', `${STRIP_ROW + ROW_STEP}px`);
    await page.keyboard.press('ArrowUp');
    await page.keyboard.press('ArrowUp');
    await expect(page.locator(STRIP)).toHaveCSS('height', `${STRIP_ROW - ROW_STEP}px`);

    // The sideways keys are another grip's business, and step nothing here.
    await page.keyboard.press('ArrowRight');
    await expect(page.locator(STRIP)).toHaveCSS('height', `${STRIP_ROW - ROW_STEP}px`);
  });
});
