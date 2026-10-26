import { test, expect } from '@playwright/test';
import { existsSync } from 'node:fs';

import { drawnNames, readSource } from './helpers';

/**
 * The served half of the circuit seam. A drawn circuit is two lists in
 * `Shared` -- the words `trackOf` matches and the words `decoderFor` decodes --
 * and a geometry file at
 * `app/static/geometry/<word>.geojson` behind them. None of it compiles: a file
 * missing is a round that fails to load, and a file gone stale is pixels nobody
 * chose. The words come out of the sources and the geometry out of the kept
 * files; nothing needs a browser.
 *
 * What this reads is the bytes the app is served. The figures the geometry
 * was authored from are a Flix-to-Flix reading -- `circuits/src/Circuit.flix`
 * against `Motorsport.Circuit.timingMap` is `circuits/test/TestTimingMap.flix`,
 * and the byte fence (`nix run .#geometry -- survey <word>`) is what holds the
 * served file to the config -- so what is checked here is the served file
 * itself: whether it stands where the app reaches for it, and whether it is
 * internally honest. Each check reads the kept file with its own eyes -- the
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

