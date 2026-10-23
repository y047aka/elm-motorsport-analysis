// The regeneration fence's comparison: what counts as the same drawing from a
// different run, what counts as the drawing having moved, and which single
// property a live regeneration is allowed to move.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { GeometryFile } from "../circuit-geometry.ts";
import { driftOf, firstDiff } from "../geometry-drift.ts";

/** One outline and one pit lane, stamped `at`, with the outline standing at
 * `end` metres. */
function file(at: string, end = 4000): GeometryFile {
  return {
    type: "FeatureCollection",
    features: [
      {
        properties: { role: "outline", circuit: "test_circuit", surveyed_at: at, metres: [0, 2000, end] },
        geometry: { type: "LineString", coordinates: [[0, 47], [0.01, 47], [0.01, 46.99]] },
      },
      {
        properties: { role: "pit_lane", circuit: "test_circuit" },
        geometry: { type: "LineString", coordinates: [[0.01, 47], [-0.002, 46.995]] },
      },
    ],
  };
}

test("a file reproduces itself, and only the survey stamp may differ", () => {
  assert.deepEqual(driftOf(file("2026-01-01T00:00:00Z"), file("2026-01-01T00:00:00Z")), []);
  assert.deepEqual(
    driftOf(file("2026-06-01T00:00:00Z"), file("2026-01-01T00:00:00Z")),
    [],
    "surveyed_at stamps which answer a file came from, not what the drawing is",
  );
});

test("a moved degree is drift, named by feature and point", () => {
  const moved = file("x");
  (moved.features![0].geometry!.coordinates![1] as [number, number]) = [0.011, 47];
  assert.deepEqual(driftOf(moved, file("x")), ["outline: the line's points differ at point 1"]);
});

test("a changed property is drift, quoted from both sides", () => {
  const stretched = file("x", 4100);
  assert.deepEqual(driftOf(stretched, file("x")), [
    'outline: metres is [0,2000,4000] in the file, [0,2000,4100] from the answer',
  ]);

  const renamed = file("x");
  delete renamed.features![0].properties!.circuit;
  assert.deepEqual(driftOf(renamed, file("x")), ['outline: circuit is "test_circuit" in the file, absent from the answer']);
});

test("a feature held by only one side is named by role", () => {
  const noPit = file("x");
  noPit.features = noPit.features!.slice(0, 1);
  assert.deepEqual(driftOf(file("x"), noPit), ["pit_lane: only the regeneration holds it"]);
  assert.deepEqual(driftOf(noPit, file("x")), ["pit_lane: only the kept file holds it"]);
});

test("firstDiff points at the first pair that disagrees, or -1", () => {
  assert.equal(firstDiff([1, 2, 3], [1, 3, 3]), 1);
  assert.equal(firstDiff([1], [1, 2]), 1, "one line shorter than the other differs where it stops");
  assert.equal(firstDiff([1, 2], [1, 2]), -1);
});
