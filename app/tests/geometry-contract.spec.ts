import { test, expect } from '@playwright/test';
import { existsSync } from 'node:fs';

import { drawnNames, readSource } from './helpers';

/**
 * The served half of the circuit seam. A drawn circuit is two lists in
 * `Shared` -- the words `trackOf` matches and the words `decoderFor` decodes --
 * and a geometry file at
 * `app/static/geometry/<word>.geojson` behind them. None of it compiles: a file
 * missing is a round that fails to load, a file gone stale is pixels nobody
 * chose, and a decoder given the wrong lap length reads every honest geometry
 * as a lie. The words come out of the sources and the geometry out of the kept
 * files; nothing needs a browser.
 *
 * What this reads is the bytes the app is served and the Elm sources that read
 * them, and nothing else. The figures the geometry was authored from are a
 * Flix-to-Flix reading -- `circuits/src/Circuit.flix` against
 * `Motorsport.Circuit.timingMap` is `circuits/test/TestTimingMap.flix`, and the
 * byte fence (`nix run .#geometry -- survey <word>`) is what holds the served
 * file to the config -- so the checks here are the ones no Flix test can make:
 * what an Elm source states, and whether the served file stands where the app
 * reaches for it. Each one reads the kept file with its own eyes -- the
 * outline, its ascending metres, the pit lane beside it, the sectors it
 * publishes -- rather than trusting any reader's claims about them.
 */

type Outline = { properties: Record<string, never> };

/** The outline the pipeline wrote, or nothing where none is kept. */
function outline(file: unknown): Outline | null {
  const found = (file as { features: { properties?: { role?: string } }[] }).features.find(
    (feature) => feature.properties?.role === 'outline',
  );
  return found ? { properties: found.properties as Record<string, never> } : null;
}

function served(word: string): unknown {
  return JSON.parse(readSource(`app/static/geometry/${word}.geojson`));
}

test('every circuit Shared draws has its geometry where the app reaches for it', () => {
  for (const name of drawnNames()) {
    const props = outline(served(name))?.properties;
    expect(props, `${name}: the kept file holds no outline`).toBeTruthy();
    expect(props!.circuit, `${name}: the kept file is not the geometry the app reaches for`).toBe(name);
    expect(
      ['osm-centreline', 'measured-midline'],
      `${name}: the kept file claims a basis no reading knows`,
    ).toContain(props!.basis);
    expect(props!.direction, `${name}: the kept file says it runs in no direction`).toMatch(
      /^(clockwise|counter_clockwise)$/,
    );
    const metres = props!.metres as number[];
    expect(metres[metres.length - 1], `${name}: the kept file's own metres do not end at its lap`).toBeCloseTo(
      props!.lap_length_m,
      1,
    );
    for (let i = 1; i < metres.length; i++) {
      expect(metres[i], `${name}: the kept file's metres go backwards at point ${i}`).toBeGreaterThanOrEqual(
        metres[i - 1],
      );
    }
    if (props!.sectors) {
      const stretches = (props!.sectors as { stretches: number[] }).stretches;
      expect(
        stretches.reduce((sum, stretch) => sum + stretch, 0),
        `${name}: the kept file's sectors do not add up to the lap it publishes`,
      ).toBeCloseTo(props!.lap_length_m, 1);
    }
    const pit = (served(name) as { features: { properties?: { role?: string } }[] }).features.find(
      (feature) => feature.properties?.role === 'pit_lane',
    );
    expect(pit, `${name}: the kept file holds no pit lane`).toBeTruthy();
  }
});

test("a circuit's directory is named by the word the app draws it by", () => {
  for (const name of drawnNames()) {
    expect(
      existsSync(new URL(`../../circuits/${name}/overpass.json`, import.meta.url)),
      `${name} is drawn, but no kept Overpass answer stands in circuits/${name}/`,
    ).toBe(true);
  }
});

/**
 * The decoder and the drawing read one file, so one lap length is a fact about
 * that file and not a figure to carry from the config that authored it -- the
 * config's own figures are `TestTimingMap`'s and the byte fence's to keep.
 */
test('the Elm decoder is given the lap length the served geometry publishes', () => {
  const layouts: Record<string, string> = {
    cota: 'package/src/Motorsport/Wec/Circuit/Cota/Layout.elm',
    le_mans: 'package/src/Motorsport/Wec/Circuit/LeMans/Layout.elm',
  };
  for (const name of drawnNames()) {
    const given = readSource(layouts[name]).match(/Geometry\.decoder \{ lapLength = ([0-9.]+) \}/);
    expect(given, `${name}'s Layout gives no lap length to the decoder`).toBeTruthy();
    const props = outline(served(name))?.properties;
    expect(
      Number(given![1]),
      `${name}: the decoder and the geometry it decodes are given different laps`,
    ).toBeCloseTo(props!.lap_length_m, 5);
  }
});

test('the circuits drawn and decoded are one list', () => {
  const shared = readSource('app/src/Shared.elm');
  const decoded = [...clause(shared, 'decoderFor circuit =', '\n\n\n').matchAll(/"([a-z_]+)" ->/g)].map((m) => m[1]);
  expect(decoded.length, 'decoderFor decodes no circuit name').toBeGreaterThan(0);
  expect(decoded.sort(), 'decoderFor decodes something other than what trackOf draws').toEqual(drawnNames().sort());
});

/** The body of a top-level definition, up to the next one. */
function clause(source: string, start: string, end: string): string {
  const body = source.split(start)[1];
  if (!body) throw new Error(`${start} not found in Shared.elm`);
  return body.split(end)[0];
}
