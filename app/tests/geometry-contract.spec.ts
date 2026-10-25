import { test, expect } from '@playwright/test';
import { existsSync } from 'node:fs';

import { authoredCircuits, drawnNames, readSource } from './helpers';

/**
 * The served half of the circuit seam. A drawn circuit is two lists in
 * `Shared` -- the words `trackOf` matches and the words `decoderFor` decodes --
 * and a geometry file at
 * `app/static/geometry/<word>.geojson` behind them. None of it compiles: a file
 * missing is a round that fails to load, a file gone stale is pixels nobody
 * chose, and a decoder given the wrong lap length reads every honest geometry
 * as a lie. The words come out of the sources and the geometry out of the
 * kept files; nothing needs a browser.
 *
 * The figures a geometry is written from are authored once, in
 * `circuits/src/Circuit.flix`; the re-check here reads the kept file with its
 * own eyes -- the outline, its ascending metres, the pit lane beside it, the
 * sectors it publishes -- so what it judges is the bytes the app is served and
 * not a reading the pipeline shares.
 */

const authored = authoredCircuits();

/** The outline the pipeline wrote, or nothing where none is kept. */
function outline(file: unknown): { properties: Record<string, never> } | null {
  const found = (file as { features: { properties?: { role?: string } }[] }).features.find(
    (feature) => feature.properties?.role === 'outline',
  );
  return found ? { properties: found.properties as Record<string, never> } : null;
}

test('every circuit Shared draws has its geometry where the app reaches for it', async () => {
  for (const name of drawnNames()) {
    const circuit = authored[name];
    expect(circuit, `${name} is drawn, but no config authors its geometry to check it against`).toBeTruthy();
    const file = JSON.parse(readSource(`app/static/geometry/${name}.geojson`));
    const props = outline(file)?.properties;
    expect(props, `${name}: the kept file holds no outline`).toBeTruthy();
    expect(props!.circuit, `${name}: the kept file is not the geometry the config writes`).toBe(name);
    expect(
      ['osm-centreline', 'measured-midline'],
      `${name}: the kept file claims a basis no reading knows`,
    ).toContain(props!.basis);
    expect(props!.direction, `${name}: the kept file says it runs in no direction`).toMatch(
      /^(clockwise|counter_clockwise)$/,
    );
    expect(
      Math.abs(props!.lap_length_m - circuit!.lap),
      `${name}: the kept file is a different lap from the one the config authors`,
    ).toBeLessThanOrEqual(0.1);
    const metres = props!.metres as number[];
    expect(metres[metres.length - 1], `${name}: the kept file's own metres do not end at its lap`).toBeCloseTo(
      props!.lap_length_m,
      1,
    );
    for (let i = 1; i < metres.length; i++) {
      expect(metres[i], `${name}: the kept file's metres go backwards at point ${i}`).toBeGreaterThanOrEqual(metres[i - 1]);
    }
    if (circuit!.sectors.kind === 'published') {
      const stretches = props!.sectors.stretches as number[];
      expect(
        stretches.reduce((sum, stretch) => sum + stretch, 0),
        `${name}: the kept file's sectors do not add up to the published lap`,
      ).toBeCloseTo(circuit!.lap, 1);
    }
    const pit = (file as { features: { properties?: { role?: string } }[] }).features.find(
      (feature) => feature.properties?.role === 'pit_lane',
    );
    expect(pit, `${name}: the kept file holds no pit lane`).toBeTruthy();
  }
});

test("a circuit's directory is named by the word the app draws it by", () => {
  for (const name of drawnNames()) {
    expect(authored[name], `${name} is drawn, but the Flix config authors no circuit by that word`).toBeTruthy();
    expect(
      existsSync(new URL(`../../circuits/${name}/overpass.json`, import.meta.url)),
      `${name} is drawn, but no kept Overpass answer stands in circuits/${name}/`,
    ).toBe(true);
  }
});

test('the Elm decoder is given the lap length the config authors', () => {
  const layouts: Record<string, string> = {
    cota: 'package/src/Motorsport/Wec/Circuit/Cota/Layout.elm',
    le_mans: 'package/src/Motorsport/Wec/Circuit/LeMans/Layout.elm',
  };
  for (const name of drawnNames()) {
    const given = readSource(layouts[name]).match(/Geometry\.decoder \{ lapLength = ([0-9.]+) \}/);
    expect(given, `${name}'s Layout gives no lap length to the decoder`).toBeTruthy();
    expect(Number(given![1]), `${name}: the decoder and the config are given different laps`).toBeCloseTo(
      authored[name].lap,
      5,
    );
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
