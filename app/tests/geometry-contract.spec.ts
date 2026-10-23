import { test, expect } from '@playwright/test';
import { existsSync, readdirSync } from 'node:fs';
import { circuit as cota } from '../../circuits/cota/circuit.ts';
import { circuit as leMans } from '../../circuits/le_mans/circuit.ts';
import { geometryFromGeoJson } from '../../circuits/circuit-geometry.ts';
import { drawnNames, readSource } from './helpers';

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
 * The flake's geometry apps are the one list here that nothing else reads:
 * the `nix run` name, the script it runs and the script's own header are
 * three spellings of one command, and a rename of any of them fails at run
 * time with a Node message rather than at check time with a test name.
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

test("a circuit's directory is named by the word the app draws it by", () => {
  for (const name of drawnNames()) {
    expect(authored[name].script, `${name}'s config does not live in circuits/${name}/`).toBe(`circuits/${name}/circuit.ts`);
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

test('the flake commands and the circuit tools are one list', () => {
  const registered = [...readSource('flake.nix').matchAll(/geometryApp "([\w-]+)" "([\w-]+)"/g)]
    .map(([, app, script]) => ({ app, script }));
  expect(registered.length, 'the flake registers no geometry commands').toBeGreaterThan(0);

  for (const { app, script } of registered) {
    expect(existsSync(new URL(`../../circuits/${script}.ts`, import.meta.url)), `nix run .#${app} would fail: circuits/${script}.ts is not here`).toBe(true);
  }

  // A tool is a script whose own header runs itself by its own filename;
  // library modules cite other tools' usage but never their own name.
  const unwrapped = readdirSync(new URL('../../circuits/', import.meta.url))
    .filter((file) => file.endsWith('.ts'))
    .filter((file) => readSource(`circuits/${file}`).includes(`node circuits/${file}`))
    .filter((file) => !registered.some((each) => each.script === file.replace(/\.ts$/, '')));
  expect(unwrapped, `these tools name themselves commands but no geometry app registers them: ${unwrapped.join(', ')}`).toEqual([]);
});

/** The body of a top-level definition, up to the next one. */
function clause(source: string, start: string, end: string): string {
  const body = source.split(start)[1];
  if (!body) throw new Error(`${start} not found in Shared.elm`);
  return body.split(end)[0];
}
