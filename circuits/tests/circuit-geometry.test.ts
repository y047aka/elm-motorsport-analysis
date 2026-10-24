// The pipeline's own arithmetic, checked on a survey small enough to verify by
// hand: chaining, stretching, direction, the frame, and every check the app's
// runtime decoder will re-run on the bytes as they arrive.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { GeometryFile, OsmWay, Place } from "../circuit-geometry.ts";
import {
  apart,
  cumulative,
  earthRadius,
  geoJsonString,
  geometryFromGeoJson,
  lapOf,
  polylineMetres,
  reason,
  roundTenth,
  sectorLines,
} from "../circuit-geometry.ts";
import { geometryFile, squareAnswer, stretches, testCircuit } from "./fixtures.ts";

const circuit = { ...testCircuit, timingLine: { lat: 47.0, lon: 0.0 } };

test("lapOf chains the unroled ways into a lap and stretches it to the published length", () => {
  const geometry = lapOf(squareAnswer(), circuit);

  assert.equal(geometry.centreline.length, 5, "the square's four corners, closing back at the start");
  assert.equal(geometry.counts?.lap, 5);
  assert.equal(geometry.counts?.kept, 5, "nothing is a tenth-of-a-metre deviation from a straight");
  assert.equal(geometry.centreline[0].metres, 0);
  assert.equal(geometry.centreline.at(-1)!.metres, 4000, "the stretched lap ends at the published length");
  for (let at = 1; at < geometry.centreline.length; at++) {
    assert.ok(geometry.centreline[at].metres > geometry.centreline[at - 1].metres, `metres go up at point ${at}`);
  }
  assert.equal(geometry.surveyedAt, "2026-01-01T00:00:00Z");
  assert.ok(geometry.surveyedLength! < 4000, `the survey of ${geometry.surveyedLength} m was stretched, not shrunk`);
});

test("lapOf reads the way round the drawing runs", () => {
  // East, south, west and home is clockwise with north up, and the drawing's
  // y runs south like SVG's.
  assert.equal(lapOf(squareAnswer(), circuit).direction, "clockwise");

  const back = squareAnswer();
  for (const way of back.elements.filter((el): el is OsmWay => el.type === "way")) {
    way.nodes = [...way.nodes!].reverse();
  }
  assert.equal(lapOf(back, circuit).direction, "counter_clockwise");
});

test("lapOf keeps the pit lane whole and names its counts", () => {
  const geometry = lapOf(squareAnswer(), circuit);
  assert.deepEqual(
    geometry.pitLane.map((p) => [p.lat, p.lon]),
    [
      [47.0, 0.01],
      [46.995, -0.002],
    ],
  );
  assert.deepEqual(geometry.counts, { kept: 5, lap: 5, pit: 2, of: 2 });
});

test("lapOf anchors the frame at the north-west corner of the whole survey", () => {
  const { frame } = lapOf(squareAnswer(), circuit);
  assert.equal(frame.origin.lat, 47.0, "the most north of lap and pit alike");
  assert.equal(frame.origin.lon, -0.002, "the most west is the pit's end, not the lap's");
  assert.ok(frame.parallel > 46.99 && frame.parallel < 47.0, "the mean parallel of everything projected");
});

test("lapOf refuses an answer with no relation, and a relation naming a way it does not hold", () => {
  assert.throws(() => lapOf({ elements: [] }, circuit), /the answer holds no relation 999/);

  const missing = squareAnswer();
  missing.elements = missing.elements.filter((el) => el.id !== 4);
  assert.throws(() => lapOf(missing, circuit), /relation 999 names way 4, which the answer does not hold/);
});

test("lapOf reports a way the chain could not take, by what stops it", () => {
  const oneWayHome = squareAnswer();
  for (const el of oneWayHome.elements) {
    if (el.type === "way" && el.id === 4) {
      el.nodes = [1, 4];
      el.tags = { oneway: "yes" };
    }
  }
  // Way 4 is listed and reaches the chain's end, but is driven the other way;
  // the report says so, against the way's length and where its end stands.
  assert.throws(
    () => lapOf(oneWayHome, circuit),
    /ways left out of the chain: 4 is 1112 m, nearest end at where the chain stopped, driven the other way/,
  );
});

test("lapOf checks the line the lap is measured from against the published one", () => {
  const shifted = { ...circuit, timingLine: { lat: 47.05, lon: 0.05, within: 10 } };
  assert.throws(
    () => lapOf(squareAnswer(), shifted),
    /role=start is \d+\.\d m from the published timing line, which is not within 10 m/,
  );
  // and says where the relation's other lines stand, so the right role is visible.
  const withFinish = squareAnswer();
  for (const el of withFinish.elements) {
    if (el.type === "relation") el.members = [...el.members!, { type: "node", role: "finish", ref: 3 }];
  }
  assert.throws(() => lapOf(withFinish, shifted), /role=finish is \d+\.\d m from it/);

  // A circuit that publishes no line asks nothing of the role.
  assert.equal(lapOf(squareAnswer(), { ...testCircuit, timingLine: undefined }).direction, "clockwise");
});

test("geoJsonString and geometryFromGeoJson are each other's inverse on the data", () => {
  const geometry = lapOf(squareAnswer(), circuit);
  const parsed = JSON.parse(geoJsonString(circuit, geometry)) as GeometryFile;
  const read = geometryFromGeoJson(parsed, circuit);

  assert.deepEqual(
    read.centreline.map((p) => [p.lat, p.lon, p.metres]),
    geometry.centreline.map((p) => [p.lat, p.lon, p.metres]),
  );
  assert.deepEqual(read.pitLane, geometry.pitLane);
  assert.deepEqual(read.frame, geometry.frame);
  assert.equal(read.direction, geometry.direction);
  assert.deepEqual(read.sectors, { source: "a map the test circuit publishes", stretches }, "a published map travels into the file whole");
  assert.equal(read.counts, null, "a read-back file cannot say what a simplification left out");
});

test("a map the organiser re-issues per season travels into the file as nothing", () => {
  const sarthe = { ...testCircuit, sectors: { kind: "perSeason" as const, reason: "the map is re-issued every year" } };
  const parsed = JSON.parse(geoJsonString(sarthe, lapOf(squareAnswer(), sarthe))) as GeometryFile;
  assert.equal(parsed.features![0].properties?.sectors, undefined, "there are no one-set lines to carry");
});

test("geoJsonString writes degrees lon before lat, one property per line", () => {
  const written = geoJsonString(circuit, lapOf(squareAnswer(), circuit));
  const parsed = JSON.parse(written) as GeometryFile;
  assert.deepEqual(parsed.features![0].geometry!.coordinates![0], [0, 47]);
  assert.equal((written.match(/"type": "Feature"/g) ?? []).length, 2, "the outline and the pit lane");
  assert.ok(written.includes(`"metres": [0,`), "the metres array stands on one line, not one per number");
});

const read = (outline: Record<string, unknown>, coords: [number, number][] = [[0, 47], [0.01, 47], [0.01, 46.99]]) =>
  geometryFromGeoJson(JSON.parse(geometryFile({ metres: [0, 2000, 4000], ...outline }, coords)), testCircuit);

test("geometryFromGeoJson reads a well-formed file", () => {
  const geometry = read({});
  assert.equal(geometry.centreline.length, 3);
  assert.deepEqual(geometry.centreline[2], { lat: 46.99, lon: 0.01, metres: 4000 });
  assert.equal(geometry.surveyedAt, null);
  assert.equal(geometry.surveyedLength, null);
});

test("geometryFromGeoJson refuses a file whose claims disagree with its points", () => {
  assert.throws(() => read({}, []), /the outline holds no points to draw/);
  assert.throws(() => read({ metres: [0, 2000] }), /2 metres for 3 points/);
  assert.throws(() => read({ metres: [0, 3000, 2000] }), /metres go backwards at point 2/);
  assert.throws(() => read({ metres: [0, 2000, 3900] }), /the outline ends at 3900 m, not the published 4000 m/);
  assert.throws(() => read({ direction: "unknown" }), /says it runs "unknown", which is not a direction/);
});

test("geometryFromGeoJson refuses a file with no frame, and one missing either feature", () => {
  const noFrame = JSON.parse(geometryFile({ metres: [0, 2000, 4000], frame: null }, [[0, 47], [0.01, 47], [0.01, 46.99]])) as GeometryFile;
  assert.throws(() => geometryFromGeoJson(noFrame, testCircuit), /the outline carries no frame to project through/);

  const file = JSON.parse(geometryFile({ metres: [0, 2000, 4000] }, [[0, 47], [0.01, 47], [0.01, 46.99]])) as GeometryFile;
  assert.throws(
    () => geometryFromGeoJson({ features: file.features!.slice(0, 1) }, testCircuit),
    /test_circuit: the geometry holds no pit lane/,
  );
});

test("geometryFromGeoJson checks the published sectors on reading", () => {
  assert.deepEqual(read({ sectors: { stretches } }).sectors, { stretches });
  assert.throws(
    () => read({ sectors: { stretches: [2000, 1200, 700] } }),
    /the sectors add up to 3900 m, not the published 4000 m/,
  );
});

test("sectorLines names each intermediate line for the sector that begins at it", () => {
  assert.deepEqual(sectorLines({ stretches: [2000, 1500, 500] }, 4000), [
    { id: "s2", metres: 2000 },
    { id: "s3", metres: 3500 },
  ]);
  assert.deepEqual(sectorLines({ stretches: [4000] }, 4000), [], "a single stretch ends where it started");
  assert.throws(() => sectorLines({ stretches: [1, 2, 3] }, 4000), /the sectors add up to 6 m, not the published 4000 m/);
});

test("apart measures degrees as ground, east-west at the second place's parallel", () => {
  const here: Place = { lat: 47.0, lon: 0.0 };
  const degree = (Math.PI / 180) * earthRadius;
  assert.equal(apart(here, here), 0);
  assert.ok(Math.abs(apart(here, { lat: 48.0, lon: 0.0 }) - degree) < 1e-6, "a degree of latitude, on this sphere");

  const east = apart(here, { lat: 47.0, lon: 1.0 });
  assert.ok(east < degree, "a degree of longitude closes as the parallel runs north");
  assert.ok(Math.abs(east - degree * Math.cos((47 * Math.PI) / 180)) < 1e-6, "taken at the parallel of the second");
});

test("polylineMetres walks a line, cumulative measures a drawing", () => {
  assert.ok(Math.abs(polylineMetres([{ lat: 0, lon: 0 }, { lat: 0.001, lon: 0 }, { lat: 0.002, lon: 0 }]) - 222.39) < 0.01);
  assert.deepEqual(cumulative([{ x: 0, y: 0 }, { x: 3, y: 4 }, { x: 3, y: 4 }]), [0, 5, 5]);
});

test("roundTenth keeps the tenth every baseline was rendered at", () => {
  assert.equal(roundTenth(1.04), 1);
  assert.equal(roundTenth(1.05), 1.1);
  assert.equal(roundTenth(3999.949999), 3999.9);
});

test("reason says what a failure says, however it was thrown", () => {
  assert.equal(reason(new Error("a lap does not close")), "a lap does not close");
  assert.equal(reason("a runner said 502"), "a runner said 502");
});
