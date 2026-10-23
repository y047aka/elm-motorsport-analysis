// The geometry-file profile read on files built here: what passes as an
// outline and its metres, what fails a pit lane that is not a line, and how
// every failure names the file it was reading — the reading that the
// regeneration fence, the diff and the atlas guard alike run on the
// repository's real kept files.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { GeometryFile } from "../circuit-geometry.ts";
import { lineBases, outlineOf, pitLaneOf, readKeptGeometry } from "../geometry-file.ts";

const outline = (props: Record<string, unknown>, coords: [number, number][]) => ({
  properties: { role: "outline", basis: "measured-midline", ...props },
  geometry: { type: "LineString", coordinates: coords },
});
const pit = (coords?: unknown) => ({
  properties: { role: "pit_lane" },
  ...(coords === undefined ? {} : { geometry: { type: "LineString", coordinates: coords } }),
});
const file = (features: unknown[]): GeometryFile => JSON.parse(JSON.stringify({ features }));

test("outlineOf takes a file's outline, its own metres and what a report should quote", () => {
  const kept = outlineOf(
    file([outline({ basis: "measured-midline", metres: [0, 50, 100] }, [[0, 47], [0.01, 47], [0.01, 46.99]])]),
    "cota",
  );
  assert.equal(kept.name, "cota");
  assert.deepEqual(kept.props, { role: "outline", basis: "measured-midline" }, "the metres belong to the line, not the props");
  assert.deepEqual(kept.metres, [0, 50, 100]);
  assert.equal(kept.coords.length, 3);
});

test("outlineOf refuses a file by name when its claims and points disagree", () => {
  assert.throws(() => outlineOf(file([]), "cota"), /cota: no outline feature/);
  assert.throws(() => outlineOf(file([outline({}, [])]), "cota"), /the outline holds no points to draw/);
  assert.throws(
    () => outlineOf(file([outline({}, [[0, 47]])]), "cota"),
    /outline publishes no metres/,
  );
  assert.throws(
    () => outlineOf(file([outline({ metres: [0, 1] }, [[0, 47]])]), "cota"),
    /cota: 2 metres for 1 points/,
  );
  assert.throws(
    () => outlineOf(file([outline({ metres: [0, 60, 50] }, [[0, 47], [0.01, 47], [0.01, 46.99]])]), "cota"),
    /cota: metres go backwards at point 2/,
  );
});

test("outlineOf refuses a basis it does not know, and a file that names none", () => {
  assert.throws(
    () => outlineOf(file([outline({ basis: "satellite-stitch", metres: [0, 50] }, [[0, 47], [0.01, 47]])]), "cota"),
    /cota: the outline names basis "satellite-stitch", which is not a line this repository reads/,
  );
  const { properties: _properties, ...headless } = outline({ metres: [0, 50] }, [[0, 47], [0.01, 47]]);
  assert.throws(
    () => outlineOf(file([{ ...headless, properties: { role: "outline" } }]), "cota"),
    /cota: the outline names basis nothing, which is not a line this repository reads/,
  );
  for (const basis of lineBases) {
    assert.equal(outlineOf(file([outline({ basis, metres: [0, 50] }, [[0, 47], [0.01, 47]])]), "cota").props.basis, basis);
  }
});

test("pitLaneOf wants a pit lane that is a line", () => {
  assert.deepEqual(pitLaneOf(file([pit([[0, 47], [0.01, 47]])]), "cota"), [[0, 47], [0.01, 47]]);
  assert.throws(() => pitLaneOf(file([]), "cota"), /cota: the geometry holds no pit lane/);
  assert.throws(() => pitLaneOf(file([pit()]), "cota"), /cota: the pit lane holds no coordinates/);
});

test("readKeptGeometry wants a kept outline and its pit lane both present", () => {
  const kept = {
    features: [
      outline({ metres: [0, 50, 100] }, [[-97.6, 30.1], [-97.61, 30.11], [-97.62, 30.12]]),
      pit([[-97.6, 30.1], [-97.601, 30.101]]),
    ],
  };
  const read = readKeptGeometry(JSON.stringify(kept), "cota");
  assert.deepEqual(read.pit, [[-97.6, 30.1], [-97.601, 30.101]]);
  assert.deepEqual(read.metres, [0, 50, 100]);

  assert.throws(
    () => readKeptGeometry(JSON.stringify({ features: kept.features.slice(0, 1) }), "cota"),
    /cota: the geometry holds no pit lane/,
  );
});
