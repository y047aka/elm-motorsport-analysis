import { test, expect } from '@playwright/test';
import { circuit as cota } from '../scripts/cota-geometry.mjs';
import { circuit as leMans } from '../scripts/le-mans-geometry.mjs';
import { geometryFromGeoJson } from '../scripts/circuit-geometry.mjs';
import { drawnNames, readSource } from './helpers';

/**
 * The served half of the circuit seam. A drawn circuit is two lists in
 * `Shared` -- the words `trackOf` matches and the words `decoderFor` decodes --
 * and a geometry file at
 * `app/static/geometry/<word>.geojson` behind them. None of it compiles: a file
 * missing is a round that fails to load, a file gone stale is pixels nobody
 * chose, and a decoder given the wrong lap length reads every honest geometry
 * as a lie. What is read here comes out of the sources and the kept files, the
 * way the other contract specs read theirs; nothing needs a browser.
 */

const authored: Record<string, typeof cota> = { cota, le_mans: leMans };

const layouts: Record<string, string> = {
  cota: 'package/src/Motorsport/Wec/Circuit/Cota/Layout.elm',
  le_mans: 'package/src/Motorsport/Wec/Circuit/LeMans/Layout.elm',
};

test('every circuit Shared draws has its geometry where the app reaches for it', async () => {
  const names = drawnNames();
  for (const name of names) {
    const script = authored[name];
    expect(script, `${name} is drawn, but no script authors its geometry to check it against`).toBeTruthy();
    // The same checks the generator ran on the way out, run on the file as it is kept.
    const file = JSON.parse(readSource(`app/static/geometry/${name}.geojson`));
    geometryFromGeoJson(file, script);
    const outline = file.features.find((f: { properties?: { role?: string } }) => f.properties?.role === 'outline');
    expect(outline.properties.circuit, `${name}: the kept file is not the geometry the script writes`).toBe(name);
  }
});

test('the Elm decoder is given the lap length the script was given', () => {
  for (const name of drawnNames()) {
    const given = readSource(layouts[name]).match(/Geometry\.decoder \{ lapLength = ([0-9.]+) \}/);
    expect(given, `${name}'s Layout gives no lap length to the decoder`).toBeTruthy();
    expect(Number(given![1]), `${name}: the decoder and the script are given different laps`).toBeCloseTo(authored[name].lapLength, 5);
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
