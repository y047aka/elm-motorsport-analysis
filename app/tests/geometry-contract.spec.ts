import { test, expect } from '@playwright/test';

import { drawnNames, readSource } from './helpers';

/**
 * The circuit seam: the served bytes stand where the app reaches for them.
 *
 * A drawn circuit is a list in `Shared` — the words `drawingFor` matches — a
 * second list in Flix — the words `Circuit.jsonValue` can send in a summary — and
 * two files behind them, the map record at `app/static/circuit-maps/<word>.json`
 * and the geometry at `app/static/geometry/<word>.geojson`, both copied from the
 * `circuit-maps-3d` flake input by the commands that read them. None of it
 * compiles: a rename on one side alone is a round drawn as the ring with nothing
 * red, and a file missing is a round that fails to load. The words come out of
 * the sources and the files out of the synced ones; nothing needs a browser.
 *
 * The two word lists are compared here;
 * what is not compared is a geometry's contents. Whether those are internally
 * honest — a known basis, a direction, metres ascending that end at the
 * published lap, sectors adding up to it, a pit lane beside it — is a refusal of
 * `Geometry.outline` and `Geometry.pitLane`, and the upstream
 * `github:y047aka/circuit-maps-3d` pipeline's to keep: its fence reproduces every
 * published file from the kept Overpass answer.
 */

type Features = { features: { properties?: Record<string, unknown> }[] };

function outlineOf(served: Features): Record<string, unknown> | undefined {
  return served.features.find((feature) => feature.properties?.role === 'outline')
    ?.properties;
}

function served(word: string): Features {
  return JSON.parse(readSource(`app/static/geometry/${word}.geojson`));
}

test('every circuit Shared draws has its geometry where the app reaches for it', () => {
  for (const name of drawnNames()) {
    const outline = outlineOf(served(name));
    expect(outline, `${name}: the served file holds no outline`).toBeTruthy();
    expect(
      outline!.circuit,
      `${name}: the served file is not the geometry the app reaches for`,
    ).toBe(name);
  }
});

test('every circuit Shared draws has its map record where the app reaches for it', () => {
  for (const name of drawnNames()) {
    const record = JSON.parse(readSource(`app/static/circuit-maps/${name}.json`));
    expect(
      typeof record.lengths?.centerline?.metres,
      `${name}: the map record gives no centreline to check the geometry against`,
    ).toBe('number');
  }
});

/** The words `Circuit.jsonValue` can send, which are the words a summary can
 * carry. Flix closes the module's last definition with a `}` at column nought,
 * which is where the body ends. */
function sentNames(): string[] {
  const backendSource = readSource('backend/src/Motorsport/Circuit.flix');
  const body = backendSource.split('pub def jsonValue')[1]?.split('\n}')[0] ?? '';
  const names = [...body.matchAll(/=>\s*"([a-z_]+)"/g)].map((m) => m[1]);
  expect(names.length, 'Circuit.jsonValue sends no circuit name').toBeGreaterThan(0);
  return names;
}

test('every circuit Shared draws is one Flix can name', () => {
  const sent = sentNames();
  const drawn = drawnNames();
  expect(drawn.length, 'Shared.drawingFor matches no circuit name').toBeGreaterThan(0);
  for (const name of drawn) {
    expect(sent, `Shared.elm draws "${name}", a circuit no summary can name`).toContain(name);
  }
});

test('the circuits with drawings here are drawn', () => {
  expect(drawnNames().sort()).toEqual(['barcelona', 'cota', 'fuji', 'imola', 'le_mans', 'monza', 'sao_paulo', 'spa']);
});
