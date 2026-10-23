// The atlas line's shape checks and guards on features built here: what passes
// as a line, a place or a fraction of a lap; what keeps one circuit's evidence
// from being filed as another's; and the file that comes out the other end.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { Circuit } from "../circuit-geometry.ts";
import { atlasFileText, checkIdentity, lineOf, markerOf, placeOf, signed } from "../atlas-line.ts";
import type { AtlasFeature } from "../atlas-line.ts";
import { cotaLike } from "./fixtures.ts";

const circuit: Circuit = cotaLike;

const feature = (properties: AtlasFeature["properties"], coordinates?: unknown): AtlasFeature => ({
  properties,
  geometry: coordinates === undefined ? undefined : { coordinates: coordinates as never },
});

test("lineOf takes an outline's line and refuses anything without one", () => {
  const outline = feature({ role: "outline" }, [[-97.6, 30.1], [-97.61, 30.11]]);
  assert.deepEqual(lineOf(outline), [
    [-97.6, 30.1],
    [-97.61, 30.11],
  ]);
  assert.throws(() => lineOf(feature({ role: "outline" })), /the atlas outline holds no line to measure/);
  assert.throws(() => lineOf(feature({ role: "outline" }, [[-97.6, 30.1]])), /holds no line to measure/, "one point is not a line");
  assert.throws(() => lineOf(feature({ role: "outline" }, "not a line")), /holds no line to measure/);
});

test("placeOf reads a marker's Point, and markerOf its fraction of the lap", () => {
  assert.deepEqual(placeOf(feature({ role: "corner" }, [-97.6, 30.1])), { lat: 30.1, lon: -97.6 });
  assert.throws(() => placeOf(feature({ role: "corner" })), /the atlas corner carries no point/);
  assert.throws(() => placeOf(feature({ role: "pit_entry" }, [[-97.6, 30.1]])), /the atlas pit_entry carries no point/);
  assert.throws(() => placeOf(feature({} as AtlasFeature["properties"], "x")), /the atlas feature carries no point/);

  assert.equal(markerOf(feature({ role: "corner", marker: 0.5 })), 0.5);
  assert.equal(markerOf(feature({ role: "corner", marker: 0 })), 0, "the start of the lap is a real place");
  assert.throws(() => markerOf(feature({ role: "corner" })), /the atlas corner carries no marker/);
  assert.throws(() => markerOf(feature({ role: "corner", marker: Number.NaN })), /carries no marker/, "NaN would be measured at NaN m");
});

test("checkIdentity refuses a file that names another circuit, and trusts an anonymous one", () => {
  checkIdentity(undefined, "cota");
  checkIdentity("cota", "cota");
  assert.throws(
    () => checkIdentity("le_mans", "cota"),
    /the atlas file names itself 'le_mans', not 'cota' — it is not this circuit's line/,
  );
});

test("atlasFileText writes the atlas line at its own length, saying so", () => {
  const coords: [number, number][] = [
    [-97.6, 30.1],
    [-97.61, 30.11],
    [-97.62, 30.12],
  ];
  const corners = [feature({ role: "corner", id: "T1", marker: 0.02, direction: "right" }, [-97.605, 30.105])];
  const pits = [feature({ role: "pit_entry", name: "Pit Entry", marker: 0.95 }, [-97.615, 30.115])];
  const written = atlasFileText(circuit, coords, corners, pits, [0, 2750.14, 5500.23]);

  const file = JSON.parse(written) as { features: { properties: Record<string, unknown>; geometry: unknown }[] };
  assert.equal(file.features.length, 3, "outline, corner and pit");

  const outline = file.features[0].properties;
  assert.equal(outline.basis, "measured-midline", "a measurement is not mistaken for a survey");
  assert.equal(outline.stretched, false, "the claim a reader sees first");
  assert.equal(outline.lap_length_m, 5500.2, "its own length, to the tenth, not the published lap");
  assert.deepEqual(outline.metres, [0, 2750.1, 5500.2]);
  assert.equal(outline.source, "https://example.org/cota.geojson");
  assert.equal(outline.license, "ODbL");
  assert.deepEqual(file.features[0].geometry, { type: "LineString", coordinates: coords });

  assert.deepEqual(file.features[1].properties, { role: "corner", id: "T1", marker: 0.02, direction: "right" });
  assert.deepEqual(file.features[2].properties, { role: "pit_entry", name: "Pit Entry", marker: 0.95 });
});

test("signed says which line is longer", () => {
  assert.equal(signed(1.23), "+1.2");
  assert.equal(signed(-0.04), "-0.0");
  assert.equal(signed(0), "+0.0");
});
