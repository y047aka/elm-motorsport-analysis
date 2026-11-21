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
const CORNER_ROOM = readConstant('cornerRoom', floatSource, /\ncornerRoom =\n\s+(\d+)/);

const FLOAT = '[data-tracker-float]';
const STRIP = '#column-strip';

/** The map's two presses, found by what they are called. Neither one carries the
 * state: the browser keeps whether the popover is open, the column's press stays `◱`
 * forever, and the ✕ lives in the map's own corner -- the only way back. */
const floatTrigger = (page: Page) =>
  page.locator(TRACKER_COLUMN).getByRole('button', { name: 'Float the track map over the columns' });
const floatClose = (page: Page) =>
  page.getByRole('button', { name: 'Close the floating track map' });

/** The box's navigation, which the pointer over the box calls out, PiP-like. */
const chrome = (page: Page): Locator => page.locator(`${FLOAT} [data-tracker-chrome]`);

/** The four edges the box is sized by, found by the words they are called by. The two
 * away from the corner it is stood at grow it up and left; the two at that corner take
 * the box along with the size. */
const edgeGrip = (page: Page, edge: 'left' | 'right' | 'top' | 'bottom'): Locator =>
  page.getByRole('separator', { name: `Resize the floating track map from the ${edge}` });
const leftGrip = (page: Page): Locator => edgeGrip(page, 'left');
const rightGrip = (page: Page): Locator => edgeGrip(page, 'right');
const topGrip = (page: Page): Locator => edgeGrip(page, 'top');
const bottomGrip = (page: Page): Locator => edgeGrip(page, 'bottom');

/** The four corners, each the meeting of two edges and the one grip that grows both
 * sizes at once. The cursor says which diagonal it lies along; the two corners of one
 * diagonal share it.
 */
const cornerGrip = (page: Page, corner: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'): Locator =>
  page.getByRole('separator', { name: `Resize the floating track map from its ${corner} corner` });
const northWestGrip = (page: Page): Locator => cornerGrip(page, 'top-left');
const northEastGrip = (page: Page): Locator => cornerGrip(page, 'top-right');
const southWestGrip = (page: Page): Locator => cornerGrip(page, 'bottom-left');
const southEastGrip = (page: Page): Locator => cornerGrip(page, 'bottom-right');

/** The drawing itself: the surface a pointer is read on. A drag anywhere on it carries the
 * box, PiP-like; the right button's drag and a two-finger scroll turn the map instead. */
const surface = (page: Page): Locator => page.locator(`${FLOAT} [data-tracker-surface]`);

/** What the circuit is drawn as. The bytes change when the camera is turned and not when the
 * box is carried, which is how the two drags are told apart here. */
const drawnBytes = async (page: Page): Promise<string> =>
  await page
    .locator(`${FLOAT} svg`)
    .first()
    .innerHTML();

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

  test('is closed until the column asks for it, and costs the strip nothing', async ({ page }) => {
    // The box is on the page -- a `popovertarget` resolves by id, so the element has
    // to be there to be shown -- but the UA keeps a closed popover out of layout, and
    // the drawing inside it is not built. That is the difference between this and the
    // row below the strip.
    await expect(page.locator(FLOAT)).toBeHidden();
    const before = await box(page, STRIP);

    await floatTrigger(page).click();
    await expect(page.locator(FLOAT)).toBeVisible();

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

    // The grip along the left edge says which bar it is. The bounds the size is held
    // between are the Elm's and are said nowhere on it.
    await expect(leftGrip(page)).toHaveAttribute('aria-orientation', 'vertical');
    await expect(leftGrip(page)).not.toHaveAttribute('aria-valuenow');

    // The pointer is the only way in: no key reaches the grip and it is no tab stop, so
    // the cursor along the edge is the whole affordance. Nothing lights under the
    // pointer, and the grip takes a background only while it is held.
    await expect(leftGrip(page)).toHaveCSS('cursor', 'col-resize');
    await expect(leftGrip(page)).not.toHaveAttribute('tabindex');
    await leftGrip(page).hover();
    await expect(leftGrip(page)).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');

    // Left is away from the corner the box is stood at, so a travel left widens
    // it -- and the right edge, the anchor, does not move.
    await carryGrip(page, leftGrip(page), -120, 0);
    const wider = await box(page, FLOAT);
    expect(wider.width).toBeCloseTo(FLOAT_WIDTH + 120, 0);
    expect(wider.x + wider.width).toBeCloseTo(opened.x + opened.width, 0);
    expect(wider.y).toBeCloseTo(opened.y, 0);
    await page.mouse.up();

    // The grip along the top edge is the height's, and goes the same way.
    await expect(topGrip(page)).toHaveAttribute('aria-orientation', 'horizontal');

    // A grip centres its mark by its tracks rather than by its item: a glyph taller
    // than the 8px these are high hangs below the grip under `place-items`, which
    // centres an item within its own track.
    await expect(topGrip(page)).toHaveCSS('align-content', 'center');
    await expect(page.locator('#standings-resize-grip')).toHaveCSS('align-content', 'center');

    await carryGrip(page, topGrip(page), 0, -100);
    const taller = await box(page, FLOAT);
    expect(taller.height).toBeCloseTo(FLOAT_HEIGHT + 100, 0);
    expect(taller.y + taller.height).toBeCloseTo(opened.y + opened.height, 0);
    await page.mouse.up();

    // The fence the size is held between is the Elm's, and it bites: a travel past the
    // narrowest leaves the box at it, and the anchor edge does not move.
    await carryGrip(page, leftGrip(page), 400, 0);
    const narrow = await box(page, FLOAT);
    expect(narrow.width).toBeCloseTo(WIDTH_MIN, 0);
    expect(narrow.x + narrow.width).toBeCloseTo(opened.x + opened.width, 0);
    await page.mouse.up();

    // Neither of these two grips marks itself: the cursor along the edge is the whole
    // affordance here, unlike the standings' `⋮` along a column edge.
    await expect(leftGrip(page)).toHaveText('');
    await expect(topGrip(page)).toHaveText('');
  });

  test('grows down and right from the corner it is anchored at, and stops at the window', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // A travel at the anchored edge moves that edge and takes the box with it, so the
    // edge opposite stays where it was.
    await carryGrip(page, rightGrip(page), -200, 0);
    expect((await box(page, FLOAT)).x).toBeCloseTo(opened.x, 0);
    await page.mouse.up();

    // And the window stops it: the box grows by the room its corner left and no
    // further, so its own edge lands on the window's -- the shrink above gave all of
    // that room back, and the pointer goes well past it.
    await carryGrip(page, rightGrip(page), 260, 0);
    const stopped = await box(page, FLOAT);
    expect(stopped.width).toBeCloseTo(FLOAT_WIDTH + CORNER_ROOM, 0);
    expect(stopped.x + stopped.width).toBeCloseTo(opened.x + opened.width + CORNER_ROOM, 0);
    await page.mouse.up();

    // Carried away from the corner, the two anchored grips have the room the carry left.
    await carryGrip(page, surface(page), -400, -200);
    await page.mouse.up();
    const stood = await box(page, FLOAT);

    await carryGrip(page, rightGrip(page), 200, 0);
    const wider = await box(page, FLOAT);
    expect(wider.width).toBeCloseTo(FLOAT_WIDTH + CORNER_ROOM + 200, 0);
    expect(wider.x).toBeCloseTo(stood.x, 0);
    await page.mouse.up();

    await carryGrip(page, bottomGrip(page), 0, 150);
    const taller = await box(page, FLOAT);
    expect(taller.height).toBeCloseTo(FLOAT_HEIGHT + 150, 0);
    expect(taller.y).toBeCloseTo(stood.y, 0);
    await page.mouse.up();
  });

  test('grows both ways at once from a corner, and says which diagonal it is', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // The pointer is the only way in, as along the edges: no key reaches a corner, it is
    // no tab stop, and it marks nothing. What it does say is which way the box grows.
    await expect(northWestGrip(page)).toHaveCSS('cursor', 'nwse-resize');
    await expect(southEastGrip(page)).toHaveCSS('cursor', 'nwse-resize');
    await expect(northEastGrip(page)).toHaveCSS('cursor', 'nesw-resize');
    await expect(southWestGrip(page)).toHaveCSS('cursor', 'nesw-resize');
    await expect(northWestGrip(page)).toHaveText('');
    await expect(northWestGrip(page)).not.toHaveAttribute('tabindex');

    // A corner is where two bars meet, and `aria-orientation` has no word for it.
    await expect(northWestGrip(page)).not.toHaveAttribute('aria-orientation');

    // One press, one pointer, and both sizes go by their own axis's travel. The two edges
    // the box is anchored at stay where they were: this corner is away from them.
    await carryGrip(page, northWestGrip(page), -80, -60);
    const grown = await box(page, FLOAT);
    expect(grown.width).toBeCloseTo(FLOAT_WIDTH + 80, 0);
    expect(grown.height).toBeCloseTo(FLOAT_HEIGHT + 60, 0);
    expect(grown.x + grown.width).toBeCloseTo(opened.x + opened.width, 0);
    expect(grown.y + grown.height).toBeCloseTo(opened.y + opened.height, 0);
    await page.mouse.up();
  });

  test('stops at the window on both axes at once, at the corner it is stood at', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // The corner the box is stood at grows into the room its corner left of the window and
    // no further, each axis on its own: the box's own edges land on the window's, and the
    // corner opposite stays where it was. The pointer goes far past both ceilings.
    await carryGrip(page, southEastGrip(page), 300, 300);
    const clamped = await box(page, FLOAT);
    expect(clamped.width).toBeCloseTo(FLOAT_WIDTH + CORNER_ROOM, 0);
    expect(clamped.height).toBeCloseTo(FLOAT_HEIGHT + CORNER_ROOM, 0);
    expect(clamped.x).toBeCloseTo(opened.x, 0);
    expect(clamped.y).toBeCloseTo(opened.y, 0);
    expect(clamped.x + clamped.width).toBeCloseTo(opened.x + opened.width + CORNER_ROOM, 0);
    expect(clamped.y + clamped.height).toBeCloseTo(opened.y + opened.height + CORNER_ROOM, 0);
    await page.mouse.up();

    // Carried away from the corner, the same grip has the room the carry left, and the
    // corner the box now stands at again stays.
    await carryGrip(page, surface(page), -300, -200);
    await page.mouse.up();
    const stood = await box(page, FLOAT);

    await carryGrip(page, southEastGrip(page), 150, 100);
    const grown = await box(page, FLOAT);
    expect(grown.width).toBeCloseTo(FLOAT_WIDTH + CORNER_ROOM + 150, 0);
    expect(grown.height).toBeCloseTo(FLOAT_HEIGHT + CORNER_ROOM + 100, 0);
    expect(grown.x).toBeCloseTo(stood.x, 0);
    expect(grown.y).toBeCloseTo(stood.y, 0);
    await page.mouse.up();
  });

  test('grows as far as the window, and no further', async ({ page }) => {
    await floatTrigger(page).click();
    const { width: windowW, height: windowH } = (await page.viewportSize())!;

    // The fences say how small the box may go and nothing more: the window is the only
    // ceiling, and it stops every edge on its own. So a corner pulled far up and left
    // leaves the box standing on the window's own corner, filling it.
    await carryGrip(page, northWestGrip(page), -1400, -1000);
    const filled = await box(page, FLOAT);
    expect(filled.width).toBeCloseTo(windowW - CORNER_ROOM, 0);
    expect(filled.height).toBeCloseTo(windowH - CORNER_ROOM, 0);
    expect(filled.x).toBeCloseTo(0, 0);
    expect(filled.y).toBeCloseTo(0, 0);
    await page.mouse.up();
  });

  test('the drawing keeps the shape of the box it is stood in', async ({ page }) => {
    await floatTrigger(page).click();

    /**
     * A fixed viewBox letterboxes inside a box of another shape, and the letterbox is
     * invisible in a screenshot of a box that happens to be the same shape as the
     * drawing. So what is asserted is the drawing's own proportions against the box it
     * was fitted to -- at the box the map opens at, and after the reader makes it
     * another shape.
     */
    const proportions = async () => {
      const viewBox = (await page.locator(`${FLOAT} svg`).first().getAttribute('viewBox'))!;
      const [, , w, h] = viewBox.split(' ').map(Number);
      const stood = (await page.locator(`${FLOAT} [data-tracker-surface]`).boundingBox())!;
      return { drawing: w / h, stood: stood.width / stood.height };
    };

    const opened = await proportions();
    expect(opened.drawing).toBeCloseTo(opened.stood, 1);

    // A taller box is a taller drawing, not the same drawing standing in the middle of a
    // taller box.
    await carryGrip(page, topGrip(page), 0, -200);
    await page.mouse.up();
    const taller = await proportions();
    expect(taller.drawing).toBeCloseTo(taller.stood, 1);
    expect(taller.drawing).toBeLessThan(opened.drawing - 1);
  });

  test('is carried by a drag anywhere on the drawing, PiP-like, at the size it was measured at', async ({
    page,
  }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);
    const drawn = await drawnBytes(page);

    await carryGrip(page, surface(page), -180, -120);
    await expectBox(page, { x: opened.x - 180, y: opened.y - 120 });
    const moved = await box(page, FLOAT);

    // A carry moves the box, resizes nothing, and leaves the circuit facing the way it was.
    expect(moved.width).toBeCloseTo(FLOAT_WIDTH, 0);
    expect(moved.height).toBeCloseTo(FLOAT_HEIGHT, 0);
    expect(await drawnBytes(page), 'the map did not turn').toBe(drawn);
    await page.mouse.up();

    // The next carry starts from where the box was left, not from the corner.
    await carryGrip(page, surface(page), 60, 40);
    await expectBox(page, { x: opened.x - 180 + 60, y: opened.y - 120 + 40 });
    await page.mouse.up();
  });

  test('cannot be carried out of the window, however far the pointer goes', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    // Past the corner it is stood at there is only the gutter it is stood in, and the
    // window's own edge is where the box stops.
    await carryGrip(page, surface(page), 400, 400);
    await expectBox(page, { x: opened.x + 10, y: opened.y + 10 });
    await page.mouse.up();

    // The other way: a pointer thrown 5000px away leaves the box whole, its own
    // corner on the window's.
    await carryGrip(page, surface(page), -5000, -5000);
    await expectBox(page, { x: 0, y: 0 });
    const moved = await box(page, FLOAT);
    expect(moved.width).toBeCloseTo(FLOAT_WIDTH, 0);
    expect(moved.height).toBeCloseTo(FLOAT_HEIGHT, 0);
    await page.mouse.up();

    // And back the way it came is free: the clamp stops the box, not the carry.
    await carryGrip(page, surface(page), 400, 400);
    await expectBox(page, { x: 400, y: 400 });
    await page.mouse.up();
  });

  test('steps the box by the arrow keys the drawing answers to', async ({ page }) => {
    await floatTrigger(page).click();
    const opened = await box(page, FLOAT);

    await surface(page).focus();
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.press('ArrowUp');
    await expectBox(page, { x: opened.x - MOVE_STEP, y: opened.y - MOVE_STEP });

    // Both axes go back, and the box is where it was.
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('ArrowDown');
    await expectBox(page, { x: opened.x, y: opened.y });
  });

  test('turns under a drag with the right button, and the box stays where it stood', async ({
    page,
  }) => {
    await floatTrigger(page).click();
    const before = await box(page, FLOAT);
    const drawn = await drawnBytes(page);
    const stood = (await surface(page).boundingBox())!;
    const cx = stood.x + stood.width / 2
    const cy = stood.y + stood.height / 2

    await page.mouse.move(cx, cy)
    await page.mouse.down({ button: 'right' })
    await page.mouse.move(cx + 200, cy + 120, { steps: 10 })
    await page.mouse.up({ button: 'right' })

    // The map turned...
    await expect.poll(() => drawnBytes(page), { timeout: 2000 }).not.toBe(drawn);

    // ...and nothing slid: the right button's drag is the turn, the left one the carry.
    const after = await box(page, FLOAT);
    expect(after.x).toBeCloseTo(before.x, 0);
    expect(after.y).toBeCloseTo(before.y, 0);
  });

  test('turns under a two-finger scroll, and the box stays where it stood', async ({ page }) => {
    await floatTrigger(page).click();
    const before = await box(page, FLOAT);
    const drawn = await drawnBytes(page);
    const stood = (await surface(page).boundingBox())!;

    await page.mouse.move(stood.x + stood.width / 2, stood.y + stood.height / 2);
    await page.mouse.wheel(240, 0);

    await expect.poll(() => drawnBytes(page), { timeout: 2000 }).not.toBe(drawn);
    const after = await box(page, FLOAT);
    expect(after.x).toBeCloseTo(before.x, 0);
    expect(after.y).toBeCloseTo(before.y, 0);
  });

  test('its navigation waits for the pointer over the box, PiP-like', async ({ page }) => {
    await floatTrigger(page).click();
    await page.mouse.move(0, 0);
    await expect(chrome(page)).toHaveCSS('opacity', '0');
    await expect(chrome(page)).toHaveCSS('pointer-events', 'none');

    await page.locator(FLOAT).hover();
    await expect(chrome(page)).toHaveCSS('opacity', '1');
    await expect(chrome(page)).toHaveCSS('pointer-events', 'auto');
  });

  test('opens from the column corner and closes from its own', async ({ page }) => {
    await expect(floatTrigger(page)).toHaveCount(1);

    // The ✕ is on the page from the first frame, but a closed popover keeps its
    // subtree out of the accessibility tree, so there is no press to find.
    await expect(floatClose(page)).toHaveCount(0);

    await floatTrigger(page).click();
    await expect(page.locator(FLOAT)).toBeVisible();

    // The way back is in the map's own corner, and the column keeps saying `◱`.
    await expect(floatTrigger(page)).toHaveCount(1);
    await expect(floatClose(page)).toHaveCount(1);

    // Nothing outside the map closes it: a `manual` popover is not dismissed by a
    // press beside it, so the columns go on being worked while the map is up. The ✕ is the
    // pointer's, and has to be called out by a hover before it can be pressed.
    await page.locator(FLOAT).hover();
    await floatClose(page).click();
    await expect(page.locator(FLOAT)).toBeHidden();
    await expect(floatTrigger(page)).toHaveCount(1);
  });
});
