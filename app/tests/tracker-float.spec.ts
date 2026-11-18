import { test, expect, Locator, Page } from '@playwright/test';
import { waitForPageReady, setLapCount, readConstant, readSource, expectSurveyedLap, TRACKER_COLUMN, COTA } from './helpers';

/**
 * A map stood *over* the strip rather than taking a row of it is a claim about the
 * page's boxes, and a screenshot of a page that kept its height by some other
 * means would look the same. So nothing here is pixels: which corner the box is
 * anchored to, what the strip measures before and after the box appears, how far
 * each grip takes it, and where a carry leaves it. The box it opens at and the
 * bounds the grips hold it between are read out of the Elm that decides them.
 */
const floatSource = readSource('app/src/Page/Wec/Float.elm');
const shiftSource = readSource('app/src/Page/Wec/Shift.elm');

const MOVE_STEP = readConstant('step', shiftSource, /\nstep =\n\s+(\d+)/);

const FLOAT_WIDTH = readConstant('defaultWidth', floatSource, /\ndefaultWidth =\n\s+(\d+)/);
const FLOAT_HEIGHT = readConstant('defaultHeight', floatSource, /\ndefaultHeight =\n\s+(\d+)/);
const WIDTH_MIN = readConstant('widthFence.min', floatSource, /widthFence =\n\s*\{[^}]*min = (\d+)/);
const WIDTH_MAX = readConstant('widthFence.max', floatSource, /widthFence =\n\s*\{[^}]*max = (\d+)/);
const WIDTH_STEP = readConstant('widthFence.step', floatSource, /widthFence =\n\s*\{[^}]*step = (\d+)/);
const HEIGHT_STEP = readConstant('heightFence.step', floatSource, /heightFence =\n\s*\{[^}]*step = (\d+)/);

const FLOAT = '[data-tracker-float]';
const STRIP = '#column-strip';

/** The map's two presses, found by what they are called: the column's own `◱`
 * while it is hidden, the ✕ every overlay here closes with once it is not. The ✕
 * is drawn twice when the map is up, and the press in the column turns back into
 * a `◱` again. */
const floatTrigger = (page: Page) =>
  page.locator(TRACKER_COLUMN).getByRole('button', { name: 'Float the track map over the columns' });
const floatClose = (page: Page) =>
  page.getByRole('button', { name: 'Close the floating track map' });

const widthGrip = (page: Page): Locator =>
  page.getByRole('separator', { name: "Resize the floating track map's width" });
const heightGrip = (page: Page): Locator =>
  page.getByRole('separator', { name: "Resize the floating track map's height" });

/** The grip the box is carried by. The circuit itself takes a drag to turn, so the
 * two drags have to be told apart by where they are pressed. */
const moveGrip = (page: Page): Locator =>
  page.getByRole('button', { name: 'Move the floating track map' });

const box = async (page: Page, selector: string) => (await page.locator(selector).boundingBox())!;

/**
 * Wait until the box has been drawn where it is expected. Elm renders on an animation
 * frame, so a `boundingBox` read taken straight after a keypress can still show the
 * frame before it, and a carry's last move lands a frame after the pointer stops.
 */
async function expectBox(page: Page, expected: { x: number; y: number }) {
  await expect
    .poll(async () => {
      const { x, y } = await box(page, FLOAT);
      return `${Math.round(x)},${Math.round(y)}`;
    })
    .toBe(`${Math.round(expected.x)},${Math.round(expected.y)}`);
}

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
    // where it stands. The map is stood over it, so it gives up nothing.
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

    // Every grip centres its glyph by its tracks rather than by its item: a glyph
    // taller than the 8px this one is high hangs below the grip under
    // `place-items`, which centres an item within its own track.
    await expect(heightGrip(page)).toHaveCSS('align-content', 'center');
    await expect(page.locator('#standings-resize-grip')).toHaveCSS('align-content', 'center');

    await carryGrip(page, heightGrip(page), 0, -100);
    const taller = await box(page, FLOAT);
    expect(taller.height).toBeCloseTo(FLOAT_HEIGHT + 100, 0);
    expect(taller.y + taller.height).toBeCloseTo(opened.y + opened.height, 0);
    await page.mouse.up();
  });

  test('is carried round the page by its grip, at the size it was measured at', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // The grip is the only place a carry starts: the circuit under the pointer takes
    // a drag to turn, so the two drags are told apart by where they are pressed.
    await expect(moveGrip(page)).toHaveCount(1);
    await carryGrip(page, moveGrip(page), -180, -120);

    await expectBox(page, { x: opened.x - 180, y: opened.y - 120 });
    const moved = await box(page, FLOAT);

    // A carry moves the box and resizes nothing.
    expect(moved.width).toBeCloseTo(FLOAT_WIDTH, 0);
    expect(moved.height).toBeCloseTo(FLOAT_HEIGHT, 0);
    await page.mouse.up();

    // The next carry starts from where the box was left, not from the corner.
    await carryGrip(page, moveGrip(page), 60, 40);
    await expectBox(page, { x: opened.x - 180 + 60, y: opened.y - 120 + 40 });
    await page.mouse.up();
  });

  test('cannot be carried out of the window, however far the pointer goes', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // Past the corner it is stood at there is only the gutter it is stood in, and the
    // window's own edge is where the box stops.
    await carryGrip(page, moveGrip(page), 400, 400);
    await expectBox(page, { x: opened.x + 10, y: opened.y + 10 });
    await page.mouse.up();

    // The other way: a pointer thrown 5000px away leaves the box whole, its own
    // corner on the window's.
    await carryGrip(page, moveGrip(page), -5000, -5000);
    await expectBox(page, { x: 0, y: 0 });
    const moved = await box(page, FLOAT);
    expect(moved.width).toBeCloseTo(FLOAT_WIDTH, 0);
    expect(moved.height).toBeCloseTo(FLOAT_HEIGHT, 0);
    await page.mouse.up();

    // And back the way it came is free: the clamp stops the box, not the carry.
    await carryGrip(page, moveGrip(page), 400, 400);
    await expectBox(page, { x: 400, y: 400 });
    await page.mouse.up();
  });

  test('turns under a drag on the circuit itself, and does not slide', async ({ page }) => {
    await floatTrigger(page).click();
    const before = await box(page, FLOAT);
    const drawing = (await page.locator(`${FLOAT} svg`).boundingBox())!;

    await page.mouse.move(drawing.x + drawing.width / 2, drawing.y + drawing.height / 2);
    await page.mouse.down();
    await page.mouse.move(drawing.x + drawing.width / 2 + 200, drawing.y + drawing.height / 2 + 120, {
      steps: 10,
    });
    await page.mouse.up();

    const after = await box(page, FLOAT);
    expect(after.x).toBeCloseTo(before.x, 0);
    expect(after.y).toBeCloseTo(before.y, 0);
  });

  test('steps the box by the arrow keys its own grip answers to', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    await moveGrip(page).focus();
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.press('ArrowUp');
    await expectBox(page, { x: opened.x - MOVE_STEP, y: opened.y - MOVE_STEP });

    // Both axes go back, and the box is where it was.
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('ArrowDown');
    await expectBox(page, { x: opened.x, y: opened.y });
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
    await expect(floatTrigger(page)).toHaveCount(1);
    await expect(floatClose(page)).toHaveCount(0);

    await floatTrigger(page).click();
    await expect(page.locator(FLOAT)).toHaveCount(1);

    // Both corners take the `◱` for a ✕ once the map is up: the way back is
    // wherever the room was asked from.
    await expect(floatTrigger(page)).toHaveCount(0);
    await expect(floatClose(page)).toHaveCount(2);
    await expect(page.locator(FLOAT).getByRole('button', { name: 'Close the floating track map' })).toHaveCount(1);

    await floatClose(page).first().click();
    await expect(page.locator(FLOAT)).toHaveCount(0);
    await expect(floatTrigger(page)).toHaveCount(1);
  });
});
