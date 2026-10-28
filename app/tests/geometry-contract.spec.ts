import { test, expect } from '@playwright/test';
import { existsSync } from 'node:fs';

import { drawnNames, readSource } from './helpers';

/**
 * The circuit seam: the served bytes stand where the app reaches for them.
 *
 * A drawn circuit is two lists in `Shared` — the words `trackOf` matches and the
 * words `decoderFor` decodes — and a geometry file at
 * `app/static/geometry/<word>.geojson` behind them. None of it compiles: a rename
 * on one side alone is a round drawn as the ring with nothing red, and a file
 * missing is a round that fails to load. The words come out of the sources and
 * the geometry out of the kept files; nothing needs a browser.
 *
 * What is checked here is where each file stands and whom it says it is, and
 * nothing else. Whether its contents are internally honest — a known basis, a
 * direction, metres ascending that end at the published lap, sectors adding up to
 * it, a pit lane beside it — is a refusal of `Geometry.outline` and
 * `Geometry.pitLane`, pinned by `circuits/test/TestGeometry.flix` and re-asked of
 * the repository's real bytes by every run of the byte fence
 * (`nix run .#geometry -- survey <word>`), which reproduces the served file from
 * the kept Overpass answer. The figures the geometry was authored from are a
 * Flix-to-Flix reading — `circuits/test/TestTimingMap.flix`.
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
