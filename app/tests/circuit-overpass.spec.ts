import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * The sphere the geometry project measures its metres on is one number, and
 * one source inside the project is allowed to state it: `Apart.earthMetres`,
 * which the survey chains with and the probe counts its laps through.
 *
 * A second spelling is invisible to every compiler — two numbers disagree
 * while the project builds — and its cost is not a rounding: a probe measured
 * on the equatorial radius instead of the mean one prints 13,627 m for the lap
 * the survey measures at 13,612, and the measured lap is the one reading a
 * config is authored from. So the number stays where a reading of the
 * project's sources can find it exactly once.
 *
 * The questions the project asks OpenStreetMap are held by the project's own
 * `flix test` — `TestOverpass` spells the survey's question and the probe's —
 * and are not re-read here.
 *
 * Nothing here needs a browser.
 */

test('the project spells its sphere once', () => {
  const sources = ['Apart.flix', 'Candidates.flix', 'Probe.flix', 'Survey.flix'];
  const stated = sources
    .map((source) => readSource(`circuits/src/${source}`))
    .flatMap((text) => text.match(/63\d{5}/g) ?? []);
  expect(stated.length, 'the earth radius is not spelled exactly once across the project').toBe(1);
  expect(
    stated[0],
    'the one spelling of the earth radius is not Apart.earthMetres',
  ).toBe(readSource('circuits/src/Apart.flix').match(/63\d{5}/)![0]);
});
