// The apartness math both the diff tool and the atlas reading run on: reading
// a file's own claims, interpolating and projecting onto a line measured in
// metres of its own lap, and the overlay that draws the same reading.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { Point } from "../circuit-geometry.ts";
import { apartness, interpolate, nearestOn, outlineOf, readArgs, svgOverlay, toSegment } from "../geometry-diff.ts";

const line = (y: number): Point[] => [
  { x: 0, y },
  { x: 100, y },
];
const metres = [0, 100];

test("outlineOf takes a file's outline, its own metres and what a report should quote", () => {
  const kept = outlineOf(
    JSON.stringify({
      features: [
        {
          properties: { role: "outline", basis: "measured-midline", metres: [0, 50, 100] },
          geometry: { type: "LineString", coordinates: [[0, 47], [0.01, 47], [0.01, 46.99]] },
        },
      ],
    }),
    "cota",
  );
  assert.equal(kept.name, "cota");
  assert.deepEqual(kept.props, { role: "outline", basis: "measured-midline" }, "the metres belong to the line, not the props");
  assert.deepEqual(kept.metres, [0, 50, 100]);
  assert.equal(kept.coords.length, 3);
});

test("outlineOf refuses a file by name when its claims and points disagree", () => {
  assert.throws(() => outlineOf(`{"features": []}`, "cota"), /cota: no outline feature/);
  assert.throws(
    () => outlineOf(JSON.stringify({ features: [{ properties: { role: "outline" }, geometry: { coordinates: [] } }] }), "cota"),
    /cota: the outline publishes no metres/,
  );
  assert.throws(
    () => outlineOf(JSON.stringify({ features: [{ properties: { role: "outline", metres: [0, 1] }, geometry: { coordinates: [[0, 47]] } }] }), "cota"),
    /cota: 2 metres for 1 points/,
  );
});

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

test("toSegment clamps to a stretch and knows a point that is one", () => {
  assert.deepEqual(toSegment({ x: 4, y: 3 }, { x: 0, y: 0 }, { x: 10, y: 0 }), { distance: 3, at: 0.4 });
  assert.equal(toSegment({ x: -5, y: 0 }, { x: 0, y: 0 }, { x: 10, y: 0 }).at, 0, "before the start is at the start");
  assert.equal(toSegment({ x: 15, y: 0 }, { x: 0, y: 0 }, { x: 10, y: 0 }).at, 1, "and after the end at the end");
  assert.deepEqual(toSegment({ x: 3, y: 4 }, { x: 0, y: 0 }, { x: 0, y: 0 }), { distance: 5, at: 0 });
});

test("readArgs wants exactly two paths and free choice of the rest", () => {
  const args = readArgs(["a.geojson", "b.geojson", "--every", "10", "--svg", "out.svg"]);
  assert.ok(args.paths[0].endsWith("/a.geojson") && args.paths[1].endsWith("/b.geojson"), "resolved from the shell's cwd");
  assert.equal(args.every, 10);
  assert.equal(args.svg, "out.svg");

  assert.equal(readArgs(["a.geojson", "b.geojson"]).every, 25);
  assert.equal(readArgs(["a.geojson", "b.geojson"]).svg, null);
  assert.throws(() => readArgs(["a.geojson"]), /usage: node circuits\/geometry-diff\.ts/);
  assert.throws(() => readArgs(["a.geojson", "b.geojson", "c.geojson"]), /usage: node circuits\/geometry-diff\.ts/);
  assert.throws(() => readArgs(["a.geojson", "b.geojson", "--every", "0"]), /"0" is not a distance/);
  assert.throws(() => readArgs(["a.geojson", "b.geojson", "--every", "often"]), /"NaN" is not a distance/);
});

test("svgOverlay draws both lines and carries their provenance with them", () => {
  const kept = (name: string, basis: string, source?: string) => ({
    name,
    props: { basis, source, license: "ODbL" },
    coords: [] as [number, number][],
    metres: [],
  });
  const svg = svgOverlay(
    [kept("survey", "osm-centreline", "https://www.openstreetmap.org/relation/999"), kept("atlas", "measured-midline")],
    [
      [
        { x: 0, y: 0 },
        { x: 100, y: 0 },
      ],
      [
        { x: 0, y: 0 },
        { x: 100, y: 50 },
      ],
    ],
  );

  assert.ok(svg.startsWith("<?xml"));
  assert.ok(svg.includes('<path d="M 20.0,500.0 L 980.0,500.0" fill="none" stroke="#d43a3a"'), "the first line in red, y flipped so north is up");
  assert.ok(svg.includes('stroke="#2a6df4"'), "the second in blue");
  assert.ok(svg.includes("<!-- survey: osm-centreline — https://www.openstreetmap.org/relation/999 -->"));
  assert.ok(svg.includes("<!-- atlas: measured-midline — no source -->"), "a line with no source says it has none");
  assert.ok(svg.includes("Data: survey is © under ODbL."));
  assert.ok(svg.includes('height="520"'), "40 plus the span of both lines scaled to the fixed width");
});
