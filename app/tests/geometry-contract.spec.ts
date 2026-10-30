import { test, expect } from '@playwright/test';
import { existsSync } from 'node:fs';

import { drawnNames, readSource } from './helpers';

/**
 * The circuit seam: the served bytes stand where the app reaches for them.
 *
 * A drawn circuit is two lists in `Shared` — the words `trackOf` matches and the
 * words `decoderFor` decodes — a third list in Flix — the words
 * `Circuit.jsonValue` can send in a summary — and a geometry file at
 * `app/static/geometry/<word>.geojson` behind them. None of it compiles: a rename
 * on one side alone is a round drawn as the ring with nothing red, and a file
 * missing is a round that fails to load. The words come out of the sources and
 * the geometry out of the kept files; nothing needs a browser.
 *
 * The three word lists are compared here, one file's reading of the other two;
 * what is not compared is a geometry's contents. Whether those are internally
 * honest — a known basis, a direction, metres ascending that end at the
 * published lap, sectors adding up to it, a pit lane beside it — is a refusal of
 * `Geometry.outline` and `Geometry.pitLane`, pinned by
 * `circuits/test/TestGeometry.flix` and re-asked of the repository's real bytes
 * by every run of the byte fence (`nix run .#geometry -- survey <word>`), which
 * reproduces the served file from the kept Overpass answer. The figures the
 * geometry was authored from are a Flix-to-Flix reading —
 * `circuits/test/TestTimingMap.flix`.
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

test("a circuit's directory is named by the word the app draws it by", () => {
  for (const name of drawnNames()) {
    expect(
      existsSync(new URL(`../../circuits/${name}/overpass.json`, import.meta.url)),
      `${name} is drawn, but no kept Overpass answer stands in circuits/${name}/`,
    ).toBe(true);
  }
});

test('the circuits drawn and decoded are one list', () => {
  const shared = readSource('app/src/Shared.elm');
  const decoded = [...clause(shared, 'decoderFor circuit =', '\n\n\n').matchAll(/"([a-z_]+)" ->/g)].map((m) => m[1]);
  expect(decoded.length, 'decoderFor decodes no circuit name').toBeGreaterThan(0);
  expect(decoded.sort(), 'decoderFor decodes something other than what trackOf draws').toEqual(drawnNames().sort());
});

/** The words `Circuit.jsonValue` can send, which are the words a summary can
 * carry. Flix closes the module's last definition with a `}` at column nought,
 * which is where the body ends. */
function sentNames(): string[] {
  const flixSource = readSource('flix/src/Motorsport/Circuit.flix');
  const body = flixSource.split('pub def jsonValue')[1]?.split('\n}')[0] ?? '';
  const names = [...body.matchAll(/=>\s*"([a-z_]+)"/g)].map((m) => m[1]);
  expect(names.length, 'Circuit.jsonValue sends no circuit name').toBeGreaterThan(0);
  return names;
}

test('every circuit Shared draws is one Flix can name', () => {
  const sent = sentNames();
  const drawn = drawnNames();
  expect(drawn.length, 'Shared.trackOf matches no circuit name').toBeGreaterThan(0);
  for (const name of drawn) {
    expect(sent, `Shared.elm draws "${name}", a circuit no summary can name`).toContain(name);
  }
});

test('the circuits with drawings here are drawn', () => {
  expect(drawnNames().sort()).toEqual(['barcelona', 'cota', 'le_mans']);
});

/** The body of a top-level definition, up to the next one. */
function clause(source: string, start: string, end: string): string {
  const body = source.split(start)[1];
  if (!body) throw new Error(`${start} not found in Shared.elm`);
  return body.split(end)[0];
}
