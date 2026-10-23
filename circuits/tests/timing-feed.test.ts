// The feed readings on a CSV small enough to read here: what counts as a time,
// how a class's fastest is pooled, what the shares place where round the lap,
// and how two seasons' placements are laid against each other.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { Circuit } from "../circuit-geometry.ts";
import {
  fastestSectors,
  impliedLines,
  lineMovement,
  metres,
  movedMetres,
  msOf,
  parseFeed,
  percent,
  readArgs,
  seconds,
  sharesOf,
  speeds,
  table,
  whole,
} from "../timing-feed.ts";

const circuit: Circuit = {
  relation: 1,
  slug: "cota",
  finishRole: "start",
  lapLength: 5515,
  geojson: "x",
  script: "x",
  survey: "x",
};
const round = { ...circuit, lines: [{ id: "s2", metres: 2000 }, { id: "s3", metres: 3500 }] };

const feed = [
  "CLASS;S1;S2;S3",
  "Hypercar;60.000;70.000;80.000",
  "Hypercar;59.000;0.000;85.000",
  "LMGT3;40.000;50.000;60.000",
  "LMGT3;;;0.000",
].join("\n");

test("parseFeed reads the header's columns into one row per lap", () => {
  const rows = parseFeed(feed, "x.csv");
  assert.equal(rows.length, 4);
  assert.deepEqual(rows[1], { CLASS: "Hypercar", S1: "59.000", S2: "0.000", S3: "85.000" });
  assert.deepEqual(rows[3], { CLASS: "LMGT3", S1: "", S2: "", S3: "0.000" });
});

test("parseFeed swallows a byte-order mark, CRLF and the trailing newline, and fails a torn line", () => {
  assert.equal(parseFeed("\uFEFF" + feed + "\r\n", "x.csv").length, 4);
  assert.throws(() => parseFeed("CLASS;S1\nHypercar;1;2", "x.csv"), /x\.csv line 2 has 3 fields, not 2\./);
});

test("msOf reads a sector time, and calls a nought and a blank no time at all", () => {
  assert.equal(msOf("1:23.456", "x"), 83456);
  assert.equal(msOf("1:02:03", "x"), 3723000);
  assert.equal(msOf("0.000", "x"), null, "the lap the feed never recorded");
  assert.equal(msOf("", "x"), null);
  assert.throws(() => msOf("abc", "x"), /x cannot read "abc" as a time\./);
  assert.throws(() => msOf("1:2:3:4", "x"), /cannot read "1:2:3:4" as a time\./);
});

test("fastestSectors takes each class's fastest over every lap, noughts aside", () => {
  const best = fastestSectors(parseFeed(feed, "x.csv"), "x.csv");
  assert.deepEqual(best.get("Hypercar"), { S1: 59000, S2: 70000, S3: 80000 });
  assert.deepEqual(best.get("LMGT3"), { S1: 40000, S2: 50000, S3: 60000 }, "the all-blank lap changes nothing");
});

test("fastestSectors pools the field whole from the classes, as the summary's shares are", () => {
  const best = fastestSectors(parseFeed(feed, "x.csv"), "x.csv");
  assert.deepEqual(best.get(whole), { S1: 40000, S2: 50000, S3: 60000 });
});

test("fastestSectors refuses a class that never crossed a line, and a lap with no class", () => {
  assert.throws(
    () => fastestSectors(parseFeed("CLASS;S1;S2;S3\nAlgarve;1;2;", "x.csv"), "x.csv"),
    /Algarve recorded no time in every sector\./,
  );
  assert.throws(
    () => fastestSectors(parseFeed("CLASS;S1;S2;S3\n;1;2;3", "x.csv"), "x.csv"),
    /x\.csv line 2 names no class\./,
  );
});

test("sharesOf divides a lap the way its fastest sectors ran it", () => {
  assert.deepEqual(sharesOf({ S1: 100, S2: 200, S3: 300 }), { S1: 1 / 6, S2: 1 / 3, S3: 1 / 2 });
});

test("impliedLines places the map's intermediate lines by the shares, and not the start line", () => {
  const lines = impliedLines(new Map([["Hypercar", { S1: 1, S2: 1, S3: 1 }]]), round);
  const at = lines.get("Hypercar")!;
  assert.equal(at.length, 2, "s2 and s3 — the line the lap is measured from stands at nought and at the end");
  assert.ok(Math.abs(at[0] - 5515 / 3) < 1e-9);
  assert.ok(Math.abs(at[1] - (2 * 5515) / 3) < 1e-9);
});

test("speeds reports the mean speed over each map stretch, which the shares hide", () => {
  const kmh = speeds({ S1: 60000, S2: 60000, S3: 60000 }, round);
  assert.deepEqual(
    kmh,
    [((2000 / 60) * 3.6).toFixed(1), ((1500 / 60) * 3.6).toFixed(1), ((2015 / 60) * 3.6).toFixed(1)],
  );
});

test("lineMovement lays one season's lines against the other's", () => {
  const season = new Map([
    ["Hypercar", [1000, 3000]],
    ["Algarve", [500, 1500]],
  ]);
  const against = new Map([
    ["Hypercar", [990, 3020]],
    ["LMGT3", [700, 2100]],
  ]);
  const shift = lineMovement(season, against);
  assert.deepEqual(shift.compared, ["Hypercar"]);
  assert.deepEqual(shift.moved.get("Hypercar"), [10, -20], "signed: which way round the lap the line moved");
  assert.deepEqual(shift.oneSeasonOnly, ["Algarve", "LMGT3"]);
  assert.equal(shift.furthest, 20, "judged on the widest move of the classes that ran both seasons");
  assert.equal(lineMovement(new Map(), new Map()).furthest, 0, "nothing compared stands at nought, not at -Infinity");
});

test("sharesOf is what the export is asked to agree with", () => {
  const best = fastestSectors(parseFeed(feed, "x.csv"), "x.csv");
  const shares = sharesOf(best.get(whole)!);
  assert.ok(Math.abs(shares.S1 + shares.S2 + shares.S3 - 1) < 1e-12, "the shares are a whole lap");
});

test("readArgs reads the round, the season against, and the distance allowed", () => {
  assert.deepEqual(readArgs(["2026/cota_6h"]), { season: 2026, id: "cota_6h", against: null, tolerance: 40 });
  assert.deepEqual(readArgs(["2026/cota_6h", "--against", "2025", "--tolerance", "55.5"]), {
    season: 2026,
    id: "cota_6h",
    against: 2025,
    tolerance: 55.5,
  });
});

test("readArgs refuses everything else by name", () => {
  assert.throws(() => readArgs([]), /usage: node circuits\/check-timing-lines\.ts/);
  assert.throws(() => readArgs(["cota_6h"]), /"cota_6h" is not a <season>\/<id> like 2026\/cota_6h\./);
  assert.throws(() => readArgs(["2026/cota_6h", "extra"]), /unknown argument: extra/);
  assert.throws(() => readArgs(["2026/cota_6h", "--against", "24"]), /"24" is not a season\./);
  assert.throws(() => readArgs(["2026/cota_6h", "--tolerance", "0"]), /"0" is not a distance\./);
  assert.throws(() => readArgs(["2026/cota_6h", "--tolerance", "far"]), /"NaN" is not a distance\./);
});

test("the columns print as the sport prints them", () => {
  assert.equal(seconds(83456), "83.456");
  assert.equal(percent(1 / 3), "33.33%");
  assert.equal(metres(1234.5), "1,234.5");
  assert.equal(movedMetres(-5.2), "-5.2 m");
  assert.equal(movedMetres(3), "+3.0 m");

  const columns: [string, number][] = [
    ["class", 7],
    ["s2", 4],
  ];
  assert.equal(table(columns, ["Hypercar", "+1.0 m"]), "Hypercar +1.0 m");
});
