import { readFileSync } from 'node:fs';
import { expect, Page } from '@playwright/test';

export const WAIT_TIMEOUT = 10_000;

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

/** The round every test drives, as a checkout keeps it. */
const ROUND_SUMMARY = new URL('../static/wec/2025/le_mans_24h.json', import.meta.url);

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
export async function setLapCount(page: Page, lap: number) {
  const summary = JSON.parse(readFileSync(ROUND_SUMMARY, 'utf8'));
  const completions: { lap: number; elapsed: string }[] = summary.index.lapCompletions;
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
