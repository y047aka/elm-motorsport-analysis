// The diff command's own two readings: the arguments it asks with, and the overlay it
// draws. The comparison they are built on is `apartness.ts`'s and tested there — as is
// the fact that the Flix command draws the same file, which `.#geometry-diff` answers
// with and `app/tests/circuits-geometry-reading.spec.ts` keeps the two readings of it
// from drifting.

import assert from "node:assert/strict";
import { test } from "node:test";

import { readArgs, svgOverlay } from "../geometry-diff.ts";

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
