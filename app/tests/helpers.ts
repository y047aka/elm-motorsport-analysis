import { existsSync, readFileSync } from 'node:fs';
import { expect, Page } from '@playwright/test';

export const WAIT_TIMEOUT = 10_000;

/** Reads a file from the repository root. */
export function readSource(pathFromRoot: string): string {
  return readFileSync(new URL(`../../${pathFromRoot}`, import.meta.url), 'utf8');
}

/**
 * Which circuits `Shared` draws to their own shape: the words it matches in `trackOf`,
 * which are the words it asks `/static/geometry/<word>.geojson` for and the words
 * Flix's `Circuit.jsonValue` sends.
 */
export function drawnNames(): string[] {
  const body = readSource('app/src/Shared.elm').split('trackOf :')[1];
  if (!body) throw new Error('trackOf not found in Shared.elm');
  return [...body.split('\nmapLoaded')[0].matchAll(/Just "([a-z_]+)" ->/g)].map((m) => m[1]);
}

/**
 * A circuit's figures as authored in `circuits/src/Circuit.flix` -- the one
 * place they are written, read back the way `circuit-contract.spec.ts` reads
 * the words out of the sources that send them. A figure the source stops
 * stating is an error named for the circuit and the figure, never a `NaN`
 * an assertion would then expect.
 */
export type AuthoredSectors =
  | { kind: 'published'; source: string; stretches: number[] }
  | { kind: 'perSeason'; reason: string };

export type Authored = {
  relation: number;
  word: string;
  timedFrom: string;
  timingLine: { lat: number; lon: number; within: number } | null;
  lap: number;
  sectors: AuthoredSectors;
  file: string;
  atlas: string | null;
  survey: string;
};

export function authoredCircuits(): Record<string, Authored> {
  const source = readSource('circuits/src/Circuit.flix');
  const bodies = source
    .split('\n    def ')
    .slice(1)
    .map((body) => body.split('\n    }')[0])
    .filter((body) => /word\s+=\s+"[a-z_]+"/.test(body));
  if (bodies.length === 0) throw new Error('circuits/src/Circuit.flix authors no circuit');

  const stated = (body: string, word: string, figure: string, matched: RegExpMatchArray | null): string => {
    if (!matched) throw new Error(`the Flix config states no ${figure} for ${word}`);
    return matched[1];
  };

  const authored: Record<string, Authored> = {};
  for (const body of bodies) {
    const word = stated(body, '?', 'word', body.match(/word\s+=\s+"([a-z_]+)"/));
    const sectorsMatch = body.match(
      /published\s*=\s*Some\(\{\s*source\s*=\s*"([^"]+)",\s*stretches\s*=\s*([\d.]+(?:\s*::\s*[\d.]+)*)\s*::\s*Nil\s*\}\s*\)/,
    );
    const perSeason = body.match(/eachSeason\s*=\s*Some\("([^"]+)"\)/);
    if (!!sectorsMatch === !!perSeason) {
      throw new Error(`${word}: the Flix config fills neither or both of its two timing maps`);
    }
    const timingLine = body.match(
      /timingLine\s*=\s*Some\(\{place\s*=\s*\{lon\s*=\s*(-?[\d.]+),\s*lat\s*=\s*(-?[\d.]+)\},\s*within\s*=\s*Some\(([\d.]+)\)\}\)/,
    );
    const atlas = body.match(/atlas\s*=\s*Some\("([^"]+)"\)/);
    authored[word] = {
      relation: Number(stated(body, word, 'relation', body.match(/relation\s*=\s*(\d+)i64/))),
      word,
      timedFrom: stated(body, word, 'timedFrom', body.match(/timedFrom\s*=\s*"([^"]+)"/)),
      timingLine: timingLine
        ? { lon: Number(timingLine[1]), lat: Number(timingLine[2]), within: Number(timingLine[3]) }
        : /timingLine\s*=\s*None/.test(body)
          ? null
          : (() => {
              throw new Error(`${word}: the Flix config says nothing about the timing line`);
            })(),
      lap: Number(stated(body, word, 'lap', body.match(/lap\s*=\s*([\d.]+)/))),
      sectors: sectorsMatch
        ? {
            kind: 'published' as const,
            source: sectorsMatch[1],
            stretches: sectorsMatch[2].split('::').map((each) => Number(each.trim())),
          }
        : { kind: 'perSeason' as const, reason: perSeason![1] },
      file: stated(body, word, 'file', body.match(/file\s*=\s*"([^"]+)"/)),
      atlas: atlas ? atlas[1] : /atlas\s*=\s*None/.test(body) ? null : (() => {
        throw new Error(`${word}: the Flix config says nothing about an atlas layer`);
      })(),
      survey: stated(body, word, 'survey', body.match(/survey\s*=\s*"([^"]+)"/)),
    };
  }
  return authored;
}

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
