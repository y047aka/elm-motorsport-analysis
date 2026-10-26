import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * What OpenStreetMap is asked, and what the answers are measured on, held in
 * strings and numbers no compiler compares.
 *
 * The asking is one Flix module — `circuits/src/Overpass.flix` spells the runners,
 * their order, the user agent, the tries per runner and the backoff once, for the
 * survey's question and the probe's alike — and both questions' shapes are pinned
 * by the project's own `flix test`: `TestOverpass` holds the survey's question, and
 * the probe's alongside it, so a question that stops short of `way(r)` — naming a
 * circuit nobody can measure, which no type says — fails there.
 *
 * What is left for this spec is the one sphere reading that reaches outside the
 * geometry project: the survey, the probe and the drawing all measure metres on it,
 * and only two of the three are inside the project. `Apart.earthMetres` is the
 * project's one spelling — the probe reads it through `Apart` rather than holding
 * its own number, which is what retired the reading of two project sources here.
 * The app's `Motorsport.Circuit.Geodesy` spells it again, in Elm, because the
 * drawing projects through it at load; a Geodesy on another sphere lays a drawing
 * whose metres are not the survey's. And a project source that spells a radius
 * again, beside `Apart`'s, re-opens the disagreement this spec used to referee —
 * so the number stays where one reading of the project's sources can find it.
 *
 * Nothing here needs a browser.
 */

/** The sphere, as a source states it: the mean earth radius in metres. */
function statedRadius(text: string, where: string): number {
  const found = text.match(/(63\d{5}(?:\.\d+)?)/);
  expect(found, `${where} states no earth radius in metres`).toBeTruthy();
  return Number(found![1]);
}

test("every drawing's metres are measured on the project's sphere", () => {
  const surveyed = statedRadius(readSource('circuits/src/Apart.flix').split('def earthMetres')[1]!, 'circuits/src/Apart.flix');
  const drawn = statedRadius(readSource('package/src/Motorsport/Circuit/Geodesy.elm'), 'Motorsport.Circuit.Geodesy');
  expect(drawn, 'the drawing projects through a different sphere from the one its survey measured').toBe(surveyed);
});

test('the project spells its sphere once', () => {
  for (const source of ['Candidates.flix', 'Probe.flix', 'Survey.flix']) {
    expect(
      readSource(`circuits/src/${source}`).match(/63\d{5}/),
      `circuits/src/${source} spells an earth radius beside Apart.earthMetres`,
    ).toBeNull();
  }
});
