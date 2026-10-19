import { existsSync, readFileSync } from 'node:fs';
import { expect, Page } from '@playwright/test';

export const WAIT_TIMEOUT = 10_000;

/** The rounds a checkout keeps, spelled as the calendar spells them. */
export const LE_MANS = '2025/le_mans_24h';
export const COTA = '2025/cota_6h';

const keptRounds = [LE_MANS, COTA];

/**
 * The summary of a round the checkout keeps.
 *
 * It has to name the circuit the round was run on. Which drawing a round gets --
 * the surveyed lap or the ring -- is the summary's `track.circuit` and nothing
 * else, so a file exported before the CLI wrote that key draws every lap as a
 * ring, and no pixel-level check can tell that a rendering of the wrong shape is
 * wrong.
 */
export function summaryOf(round: string): {
  track?: { circuit?: string };
  index: { lapCompletions: { lap: number; elapsed: string }[] };
} {
  if (!keptRounds.includes(round)) {
    throw new Error(`${round} is not a round a checkout keeps, which keeps ${keptRounds.join(' and ')}.`);
  }

  const file = new URL(`../static/wec/${round}.json`, import.meta.url);
  if (!existsSync(file)) {
    throw new Error(`There is no ${round}.json in the checkout. Write it: nix run .#cli-export -- --export-only ${round}`);
  }

  const summary = JSON.parse(readFileSync(file, 'utf8'));
  if (typeof summary.track?.circuit !== 'string') {
    throw new Error(`${round} names no circuit, so its tracker draws as a ring. Re-export it: nix run .#cli-export -- --export-only ${round}`);
  }
  return summary;
}

/** Wait until `contentSelector` is visible and the fonts have loaded. */
export async function waitForPageReady(page: Page, contentSelector: string) {
  await page.locator(contentSelector).waitFor({ state: 'visible', timeout: WAIT_TIMEOUT });
  await page.waitForFunction(async () => {
    await document.fonts.ready;
    return (
      document.fonts.check('400 12px "Inter"') &&
      document.fonts.check('600 12px "Inter"') &&
      document.fonts.check('700 12px "Inter"')
    );
  }, { timeout: WAIT_TIMEOUT });
}

/** The tracker's column, which the strip holds from page load. */
export const TRACKER_COLUMN = '[data-tracker-column]';

/**
 * Assert the tracker drew the circuit and not the ring it falls back to. Nothing
 * fails when the ring is drawn; what moved is the shape of the race. The ring's
 * lap is a circle and the surveyed lap is a polygon, which the ring's drawing has
 * none of, so the polygon says a drawing was chosen -- no baseline needed.
 */
export async function expectSurveyedLap(page: Page) {
  await expect(page.locator(`${TRACKER_COLUMN} svg polygon`)).toHaveCount(1);
}

/** `h:mm:ss.fff` or `m:ss.fff`, as the summary spells an elapsed time. */
function toMillis(elapsed: string): number {
  return elapsed
    .split(':')
    .reduce((total, part) => total * 60 + Number(part), 0) * 1000;
}

/**
 * Move the time slider to the last whole second at which the lap counter still
 * reads `lap`, the moment being read off the round's `lapCompletions`.
 *
 * The playback state is a function of the elapsed time alone, so any mid-race
 * state can be reproduced deterministically without playback. The value is set
 * through the native setter and an input event is dispatched, which Base UI's
 * slider turns into the value change the custom element reports to Elm.
 *
 * The range input belongs to Base UI and is clipped away from sight, so it is
 * waited for as attached rather than visible.
 */
export async function setLapCount(page: Page, round: string, lap: number) {
  const completions: { lap: number; elapsed: string }[] = summaryOf(round).index.lapCompletions;
  const next = completions.find((c) => c.lap === lap + 1);
  if (!next) throw new Error(`The round has no lap ${lap + 1} to stop before`);
  const seconds = Math.floor((toMillis(next.elapsed) - 1) / 1000);

  const slider = page.locator('input[type="range"]');
  await slider.waitFor({ state: 'attached', timeout: WAIT_TIMEOUT });
  // The slider renders with max="0" until the race JSON has been fetched, and a
  // value set before that is clamped back to 0. Wait for the lap data to land.
  await expect(slider).not.toHaveAttribute('max', '0', { timeout: WAIT_TIMEOUT });
  await page.evaluate((value) => {
    const el = document.querySelector('input[type="range"]') as HTMLInputElement;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!;
    setter.call(el, String(value));
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, seconds);
  await expect(slider).toHaveValue(String(seconds));
}
