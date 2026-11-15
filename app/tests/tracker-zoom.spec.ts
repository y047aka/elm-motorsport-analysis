import { test, expect, Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { waitForPageReady, setLapCount, TRACKER_COLUMN, COTA } from './helpers';

/**
 * The tracker taking the room above the columns is a row the page is laid out
 * in rather than a thing drawn, so nothing here is pixels: what is asserted is
 * where the strip came to rest and how big the circuit's own polygon ended up.
 * The row the strip keeps is read out of the class string that lays the page
 * out, so a row moved in the Elm moves the expectation with it.
 */
const eventSource = readFileSync(new URL('../src/Page/Wec/Event.elm', import.meta.url), 'utf8');
const STRIP_ROW = Number(/grid-rows-\[minmax\(0,1fr\)_minmax\(0,(\d+)px\)\]/.exec(eventSource)?.[1]);
if (!Number.isFinite(STRIP_ROW)) {
  throw new Error('the enlarged layout row is not in Page/Wec/Event.elm -- did it move?');
}

const ZOOM = '[data-tracker-zoom]';
const EXPANDED = '[data-tracker-expanded]';
const STRIP = '#column-strip';

/** The column's own toggle: the enlarged drawing carries a second one. */
const zoomIn = (page: Page) => page.locator(`${TRACKER_COLUMN} ${ZOOM}`);

/** The circuit as it comes out on screen -- the polygon, not the box it is
 * centred in, which is the full width of its card whatever the circuit's shape. */
function drawn(page: Page, selector: string) {
  return page.locator(`${selector} svg polygon`).boundingBox();
}

test.describe('the enlarged tracker', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`/wec/${COTA}`, { waitUntil: 'load' });
    await waitForPageReady(page, 'text=Lone Star Le Mans');
    await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
    await setLapCount(page, COTA, 71);
  });

  test('pushes the strip down and draws the circuit in the room it gave', async ({ page }) => {
    const before = (await page.locator(STRIP).boundingBox())!;
    const inColumn = (await drawn(page, TRACKER_COLUMN))!;

    await zoomIn(page).click();
    await expect(page.locator(EXPANDED)).toHaveCount(1);

    const strip = (await page.locator(STRIP).boundingBox())!;
    const enlarged = (await page.locator(EXPANDED).boundingBox())!;
    const onScreen = (await drawn(page, EXPANDED))!;

    // The strip went down into the row it keeps, and the tracker stands in
    // what it gave up.
    expect(strip.y).toBeGreaterThan(before.y);
    expect(strip.height).toBeCloseTo(STRIP_ROW, 0);
    expect(enlarged.y).toBeLessThan(strip.y);
    expect(enlarged.y + enlarged.height).toBeLessThanOrEqual(strip.y + 1);

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
});
