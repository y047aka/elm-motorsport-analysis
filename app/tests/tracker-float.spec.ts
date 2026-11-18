import { test, expect, Locator, Page } from '@playwright/test';
import { waitForPageReady, setLapCount, readConstant, readSource, expectSurveyedLap, TRACKER_COLUMN, COTA } from './helpers';

/**
 * A map stood *over* the strip rather than taking a row of it is a claim about the
 * page's boxes, and a screenshot of a page that kept its height by some other
 * means would look the same. So nothing here is pixels: which corner the box is
 * anchored to, what the strip measures before and after the box appears, and how
 * far each grip takes it. The box it opens at and the bounds the grips hold it
 * between are read out of the Elm that decides them.
 */
const eventSource = readSource('app/src/Page/Wec/Event.elm');

const FLOAT_WIDTH = readConstant('defaultFloatWidth', eventSource, /\ndefaultFloatWidth =\n\s+(\d+)/);
const FLOAT_HEIGHT = readConstant('defaultFloatHeight', eventSource, /\ndefaultFloatHeight =\n\s+(\d+)/);
const WIDTH_MIN = readConstant('floatWidthFence.min', eventSource, /floatWidthFence =\n\s*\{[^}]*min = (\d+)/);
const WIDTH_MAX = readConstant('floatWidthFence.max', eventSource, /floatWidthFence =\n\s*\{[^}]*max = (\d+)/);
const WIDTH_STEP = readConstant('floatWidthFence.step', eventSource, /floatWidthFence =\n\s*\{[^}]*step = (\d+)/);
const HEIGHT_STEP = readConstant('floatHeightFence.step', eventSource, /floatHeightFence =\n\s*\{[^}]*step = (\d+)/);

const FLOAT = '[data-tracker-float]';
const FLOAT_TOGGLE = '[data-tracker-float-toggle]';
const STRIP = '#column-strip';

/** The column's own trigger: `◱` while the map is hidden, the ✕ every overlay
 * here closes with once it is not. */
const floatTrigger = (page: Page) => page.locator(`${TRACKER_COLUMN} ${FLOAT_TOGGLE}`);

const widthGrip = (page: Page): Locator =>
  page.getByRole('separator', { name: "Resize the floating track map's width" });
const heightGrip = (page: Page): Locator =>
  page.getByRole('separator', { name: "Resize the floating track map's height" });

const box = async (page: Page, selector: string) => (await page.locator(selector).boundingBox())!;

/**
 * Press a grip and carry the pointer by `dx` and `dy` without letting go -- the
 * same wait the row grip and a column carry use: the grip only listens for moves
 * once Elm has drawn it held.
 */
async function carryGrip(page: Page, handle: Locator, dx: number, dy: number) {
  const handle_box = (await handle.boundingBox())!;
  const x = handle_box.x + handle_box.width / 2;
  const y = handle_box.y + handle_box.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await expect(handle).toHaveClass(/cursor-grabbing/);
  await page.mouse.move(x + dx, y + dy, { steps: 10 });
}

test.describe('the floating track map', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`/wec/${COTA}`, { waitUntil: 'load' });
    await waitForPageReady(page, 'text=Lone Star Le Mans');
    await expect(page.locator(TRACKER_COLUMN)).toHaveCount(1);
    await setLapCount(page, COTA, 71);
  });

  test('is not on the page until the column asks for it, and costs the strip nothing', async ({ page }) => {
    // Nothing is drawn, and nothing is laid out for it: the page opens without the
    // map, which is the difference between this and the row below the strip.
    await expect(page.locator(FLOAT)).toHaveCount(0);
    const before = await box(page, STRIP);

    await floatTrigger(page).click();
    await expect(page.locator(FLOAT)).toHaveCount(1);

    // The claim the whole layout rests on: the strip keeps the box it had, down to
    // where it stands. The row takes `defaultTrackerRow` of it; this takes none.
    const after = await box(page, STRIP);
    expect(after.x).toBeCloseTo(before.x, 0);
    expect(after.y).toBeCloseTo(before.y, 0);
    expect(after.width).toBeCloseTo(before.width, 0);
    expect(after.height).toBeCloseTo(before.height, 0);
  });

  test('stands over the strip at the corner it is anchored to, and draws the circuit', async ({ page }) => {
    await floatTrigger(page).click();

    await expect(page.locator(FLOAT)).toHaveCSS('width', `${FLOAT_WIDTH}px`);
    await expect(page.locator(FLOAT)).toHaveCSS('height', `${FLOAT_HEIGHT}px`);

    const float = await box(page, FLOAT);
    const strip = await box(page, STRIP);

    // Inside the strip's own box rather than beside it: the map shares the room the
    // columns are drawn in, which is what leaves the strip's height alone.
    expect(float.x).toBeGreaterThanOrEqual(strip.x);
    expect(float.y).toBeGreaterThanOrEqual(strip.y);
    expect(float.x + float.width).toBeLessThanOrEqual(strip.x + strip.width + 1);
    expect(float.y + float.height).toBeLessThanOrEqual(strip.y + strip.height + 1);

    // The circuit raised off the ground it was surveyed on, and not the ring a
    // round with no geometry falls back to.
    await expectSurveyedLap(page, FLOAT);
  });

  test('grows up and left from the corner it stands at, by a grip along each edge', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // The grip along the left edge is the width's: a vertical bar, and the range
    // the box can be taken between is said with `Range`.
    await expect(widthGrip(page)).toHaveAttribute('aria-orientation', 'vertical');
    await expect(widthGrip(page)).toHaveAttribute('aria-valuemin', `${WIDTH_MIN}`);
    await expect(widthGrip(page)).toHaveAttribute('aria-valuemax', `${WIDTH_MAX}`);
    await expect(widthGrip(page)).toHaveAttribute('aria-valuenow', `${FLOAT_WIDTH}`);

    // Left is away from the corner the box is stood at, so a travel left widens
    // it -- and the right edge, the anchor, does not move.
    await carryGrip(page, widthGrip(page), -120, 0);
    const wider = await box(page, FLOAT);
    expect(wider.width).toBeCloseTo(FLOAT_WIDTH + 120, 0);
    expect(wider.x + wider.width).toBeCloseTo(opened.x + opened.width, 0);
    expect(wider.y).toBeCloseTo(opened.y, 0);
    await page.mouse.up();

    // The grip along the top edge is the height's, and goes the same way.
    await expect(heightGrip(page)).toHaveAttribute('aria-orientation', 'horizontal');
    await carryGrip(page, heightGrip(page), 0, -100);
    const taller = await box(page, FLOAT);
    expect(taller.height).toBeCloseTo(FLOAT_HEIGHT + 100, 0);
    expect(taller.y + taller.height).toBeCloseTo(opened.y + opened.height, 0);
    await page.mouse.up();
  });

  test('steps by the arrow keys each grip answers to', async ({ page }) => {
    await floatTrigger(page).click();
    await expect(page.locator(FLOAT)).toHaveCSS('width', `${FLOAT_WIDTH}px`);

    await widthGrip(page).focus();
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator(FLOAT)).toHaveCSS('width', `${FLOAT_WIDTH + WIDTH_STEP}px`);
    await page.keyboard.press('ArrowRight');
    await expect(page.locator(FLOAT)).toHaveCSS('width', `${FLOAT_WIDTH}px`);

    // The keys along the other axis step nothing here, and vice versa.
    await heightGrip(page).focus();
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator(FLOAT)).toHaveCSS('height', `${FLOAT_HEIGHT}px`);
    await page.keyboard.press('ArrowUp');
    await expect(page.locator(FLOAT)).toHaveCSS('height', `${FLOAT_HEIGHT + HEIGHT_STEP}px`);
  });

  test('closes from either corner, and the column says which state it is in', async ({ page }) => {
    await expect(floatTrigger(page)).toHaveAttribute('aria-label', 'Float the track map over the columns');

    await floatTrigger(page).click();
    await expect(page.locator(FLOAT)).toHaveCount(1);

    // Both corners take the `◱` for a ✕ once the map is up, the way the enlarged
    // row's does: the way back is wherever the room was asked from.
    await expect(floatTrigger(page)).toHaveAttribute('aria-label', 'Close the floating track map');
    await expect(page.locator(`${FLOAT} ${FLOAT_TOGGLE}`)).toHaveAttribute('aria-label', 'Close the floating track map');

    await page.getByRole('button', { name: 'Close the floating track map' }).first().click();
    await expect(page.locator(FLOAT)).toHaveCount(0);
    await expect(floatTrigger(page)).toHaveAttribute('aria-label', 'Float the track map over the columns');
  });
});
