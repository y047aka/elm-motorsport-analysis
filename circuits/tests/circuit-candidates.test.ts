// The probe's readings without the probing: how far a place widens into a box,
// which tags could name a circuit, what a relation's own tags claim, and what
// an answer's roles measure.

import assert from "node:assert/strict";
import { test } from "node:test";

import type { OverpassAnswer } from "../circuit-geometry.ts";
import { bboxOf, describe, looksLikeACircuit, measureAnswer } from "../circuit-candidates.ts";

test("bboxOf takes a box as given and widens a centre by the radius", () => {
  assert.deepEqual(bboxOf("47.0,0.1,48.0,0.9", 5), { s: 47.0, w: 0.1, n: 48.0, e: 0.9 });

  const at47 = bboxOf("47.0,0.0", 5);
  assert.ok(Math.abs(at47.n - 47.0 - 5 / 111.32) < 1e-9, "a radius of latitude over 111.32 km per degree");
  assert.ok(at47.e - 0.0 > at47.n - 47.0, "and more degrees of longitude at the same ground distance");
  assert.ok(Math.abs(at47.s + at47.n - 94.0) < 1e-9, "the centre between its south and its north");
});

test("bboxOf refuses a box that does not open and a place that is neither", () => {
  assert.throws(() => bboxOf("48.0,0.0,47.0,1.0", 5), /the box does not open north-east/);
  assert.throws(() => bboxOf("1.0,2.0,3.0", 5), /neither a centre nor a box/);
  assert.throws(() => bboxOf("north,east", 5), /neither a centre nor a box/);
});

test("looksLikeACircuit takes the tags a chainable relation could carry", () => {
  assert.equal(looksLikeACircuit({ type: "circuit" }), true);
  assert.equal(looksLikeACircuit({ motorsport: "le_mans_series" }), true);
  assert.equal(looksLikeACircuit({ highway: "raceway" }), true);
  assert.equal(looksLikeACircuit({ sport: "motorsport" }), true);
  assert.equal(looksLikeACircuit({ type: "route", route: "raceway" }), true);
  assert.equal(looksLikeACircuit({ type: "route", route: "walking", "raceway:pit_lane": "yes" }), true);

  assert.equal(looksLikeACircuit({ type: "boundary" }), false);
  assert.equal(looksLikeACircuit({ sport: "soccer" }), false);
  assert.equal(looksLikeACircuit({ type: "route", route: "bus" }), false, "a raceway route says so in its route tag");
  assert.equal(looksLikeACircuit({}), false);
});

test("describe prints the kind, the name and the length the tags themselves claim", () => {
  assert.equal(
    describe({ type: "circuit", name: "Circuit automobile", distance: "13.626" }),
    'type=circuit  "Circuit automobile", tags say 13.626 km',
  );
  assert.equal(describe({ sport: "motor", "name:en": "COTA" }), 'sport=motor  "COTA"');
  assert.equal(describe({ type: "circuit" }), 'type=circuit  "(unnamed)"', "an unnamed relation still prints");
});

/** One relation: two unroled ways, one pit way, one named node — the roles the
 * probe reports, with ways measured in degrees so the metres are countable. */
function answer(): OverpassAnswer {
  const point = (metres: number) => [{ lat: metres / 111194.9, lon: 0 }, { lat: 0, lon: 0 }];
  return {
    elements: [
      {
        type: "relation",
        id: 7,
        members: [
          { type: "way", role: "", ref: 1 },
          { type: "way", role: "", ref: 2 },
          { type: "way", role: "pit_lane", ref: 3 },
          { type: "node", role: "start", ref: 4 },
        ],
      },
      { type: "way", id: 1, geometry: point(100) },
      { type: "way", id: 2, geometry: point(200) },
      { type: "way", id: 3, geometry: point(55) },
    ],
  };
}

test("measureAnswer counts the roles and measures the unroled ways", () => {
  const read = measureAnswer(answer(), 7);
  assert.ok(read.startsWith("lap 300 m over 2 unroled ways"), read);
  assert.ok(read.includes(", pit 55 m"), "the pit role measured apart from the lap");
  assert.ok(read.includes("roles: (none): 2 ways, pit_lane: 1 way"), "the unroled role prints as (none)");
  assert.ok(read.endsWith("; nodes: start"), "node roles are named without being measured");
});

test("measureAnswer says so when the answer holds no relation", () => {
  assert.throws(() => measureAnswer({ elements: [] }, 7), /the answer holds no relation 7/);
});
