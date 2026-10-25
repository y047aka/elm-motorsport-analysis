// The apartness math both the diff and the atlas reading run on: laying two
// lines against each other, interpolating and projecting onto a line measured in
// metres of its own lap. `circuits/src/Apart.flix` is the same four readings
// for the commands that are Flix, and these are the expectations it is held to as
// well — the same numbers, written down twice, in the two languages that compute them.
// The drawing of an overlay is the diff's own, and the reading of a file itself
// is `geometry-file.ts`'s.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { Point } from "../circuit-geometry.ts";
import { apartness, interpolate, nearestOn, toSegment } from "../apartness.ts";

const line = (y: number): Point[] => [
  { x: 0, y },
  { x: 100, y },
];
const metres = [0, 100];

test("interpolate walks a line by its own metres", () => {
  const points = line(0);
  assert.deepEqual(interpolate(points, metres, 40), { x: 40, y: 0 });
  assert.deepEqual(interpolate(points, metres, 0), { x: 0, y: 0 }, "the lap's own zero");

  const still = [{ x: 0, y: 0 }, { x: 0, y: 0 }, { x: 5, y: 0 }];
  assert.deepEqual(interpolate(still, [0, 0, 5], 2.5), { x: 2.5, y: 0 }, "a zero-length stretch is walked through, not divided by");
});

test("nearestOn projects a place onto a line and reports where that stands on its measure", () => {
  const lShape: Point[] = [
    { x: 0, y: 0 },
    { x: 10, y: 0 },
    { x: 10, y: 10 },
  ];
  const near = nearestOn({ x: 5, y: 3 }, lShape, [0, 10, 20]);
  assert.deepEqual(near, { metres: 5, distance: 3 });

  const past = nearestOn({ x: 12, y: 12 }, lShape, [0, 10, 20]);
  assert.deepEqual(past, { metres: 20, distance: Math.hypot(2, 2) }, "beyond the end it clamps to the corner, not beyond");
});

test("apartness samples one line against another at its own spacing", () => {
  const read = apartness(line(0), metres, line(5), metres, 25);
  assert.equal(read.count, 4, "0, 25, 50, 75 — the lap's own end is not sampled twice");
  assert.equal(read.mean, 5, "two parallel lines 5 apart are 5 apart everywhere");
  assert.deepEqual(read.worst, { aMetres: 0, bMetres: 0, distance: 5 }, "all equal: the first sample is the worst");
});

test("apartness refuses a line whose own metres never leave zero, rather than an unnamed reduce failure", () => {
  assert.throws(
    () => apartness([{ x: 0, y: 0 }], [0], line(5), metres, 25),
    /nothing is measured along the sampled line: its own metres end at 0 m/,
  );
  assert.throws(() => apartness([], [], line(5), metres, 25), /its own metres end at 0 m/);
});

test("toSegment clamps to a stretch and knows a point that is one", () => {
  assert.deepEqual(toSegment({ x: 4, y: 3 }, { x: 0, y: 0 }, { x: 10, y: 0 }), { distance: 3, at: 0.4 });
  assert.equal(toSegment({ x: -5, y: 0 }, { x: 0, y: 0 }, { x: 10, y: 0 }).at, 0, "before the start is at the start");
  assert.equal(toSegment({ x: 15, y: 0 }, { x: 0, y: 0 }, { x: 10, y: 0 }).at, 1, "and after the end at the end");
  assert.deepEqual(toSegment({ x: 3, y: 4 }, { x: 0, y: 0 }, { x: 0, y: 0 }), { distance: 5, at: 0 });
});
