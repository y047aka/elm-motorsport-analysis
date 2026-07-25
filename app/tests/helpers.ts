import { expect, Page } from '@playwright/test';

export const WAIT_TIMEOUT = 10_000;

/**
 * Wait until the page has finished rendering.
 * @param page Playwright page object
 * @param contentSelector Selector for page-specific content
 */
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

/**
 * Move the lap slider (RaceControl.SetCount) to the given lap.
 *
 * SetCount derives elapsed time purely from lap data, so any mid-race
 * state (positions, gaps, lap-history-based charts) can be reproduced
 * deterministically without playback (▶). The value is set through the
 * native setter and an input event is dispatched so Elm's onInput
 * receives it.
 */
export async function setLapCount(page: Page, lap: number) {
  const slider = page.locator('input[type="range"]');
  await slider.waitFor({ state: 'visible', timeout: WAIT_TIMEOUT });
  // The slider renders with max="0" until the race JSON has been fetched, and a
  // value set before that is clamped back to 0. Wait for the lap data to land.
  await expect(slider).not.toHaveAttribute('max', '0', { timeout: WAIT_TIMEOUT });
  await page.evaluate((lapCount) => {
    const el = document.querySelector('input[type="range"]') as HTMLInputElement;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!;
    setter.call(el, String(lapCount));
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, lap);
  await expect(slider).toHaveValue(String(lap));
}
