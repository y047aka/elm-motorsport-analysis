import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * What OpenStreetMap is asked is held in strings and numbers no compiler compares.
 *
 * The asking is one Flix module — `circuits/src/Overpass.flix` spells the runners,
 * their order, the user agent, the tries per runner and the backoff once, for the
 * survey's question and the probe's alike — and the probe's readings sit in the same
 * project as the survey's. What no compiler therefore still cannot see is the ground
 * those answers are measured on and the reach of the two questions. The sphere a
 * probe's metres are measured on is read out of every source that uses it — the
 * survey's `Apart.flix`, the probe's `Candidates.flix`, and the drawing's
 * `Motorsport.Circuit.Geodesy` — because a probe measuring on the equatorial radius
 * prints 13,627 m for the lap the survey measures at 13,612, and the measured lap is
 * the one reading a config is authored from. And a question that stops short of
 * `way(r)` names a circuit nobody can measure, which no type says.
 *
 * The runners, the user agent, the tries and the backoff needed a spec while the
 * probe was a second project spelling them again; one spelling needs none, and
 * `circuits/test/TestOverpass.flix` holds those readings from inside the project.
 *
 * Nothing here needs a browser.
 */

const survey = readSource('circuits/src/Apart.flix');
const asking = readSource('circuits/src/Overpass.flix');
const candidates = readSource('circuits/src/Candidates.flix');
const probe = readSource('circuits/src/Probe.flix');

/**
 * One sphere measures a probe's metres, a survey's metres and the drawing's
 * projection. Three sources hold the number, no compiler reads two of them
 * together, and a probe whose sphere differs from the survey's reports a 13.6 km
 * circuit as a 13.7 km one — which is the one reading that decides a config.
 */
test("a probe's metres are measured on the sphere the survey is measured on", () => {
  const radius = (text: string, where: string) => {
    const found = text.match(/(63\d{5}(?:\.\d+)?)/);
    expect(found, `${where} states no earth radius in metres`).toBeTruthy();
    return Number(found![1]);
  };
  const surveyed = radius(survey.split('def earthMetres')[1]!.split('\n')[0]!, 'circuits/src/Apart.flix');
  const probed = radius(candidates.split('def earthRadius')[1]!.split('\n')[0]!, 'the probe');
  const drawn = radius(readSource('package/src/Motorsport/Circuit/Geodesy.elm'), 'Motorsport.Circuit.Geodesy');
  expect(probed, 'a probe measures its laps on a different sphere from the one the geometry is measured on').toBe(
    surveyed,
  );
  expect(drawn, 'the drawing projects through a different sphere from the one its survey measured').toBe(surveyed);
});

/**
 * Both questions recurse to the relation's ways: `way(r)` is what brings the ways
 * whose roles the probe counts and whose lines the survey chains, so a question
 * that stops short of it asks about a circuit nobody measures. Where the two part
 * is after that — the survey goes on for the nodes to chain (`node(w)`) and the
 * probe stops at the geometry Overpass hands inline — and that is the difference
 * between drawing a lap and lengthening one.
 */
test('the probe asks for the ways the survey chains, and not for its nodes', () => {
  const askedByProbe = probe.split('relation(${element#id});')[1]?.split(';')[0];
  expect(askedByProbe, "the probe no longer recurses to the relation's ways").toBe('out body');
  expect(asking, "the survey no longer recurses to the relation's ways").toContain('way(r)');
  expect(asking, 'the survey no longer asks for the nodes it chains').toContain('node(w)');
  expect(probe, 'the probe asks for nodes, which is a survey\'s question and not a probe\'s').not.toContain('node(w)');
});
