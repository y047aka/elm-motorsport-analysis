// The Circuit of the Americas' config for the geometry pipeline: the relation
// to survey, the figures the circuit publishes, and the word its rounds are
// known by. What the pipeline writes and how, and where these figures come
// from and what holds them, is `circuits/README.md`.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// geometry written here is a derivative of it.

import type { Circuit } from "../circuit-geometry.ts";

export const circuit: Circuit = {
  relation: 6537729,
  slug: "cota",

  // The relation tags two nodes, `start` and `finish`, 297 m apart along the
  // lap: `finish` is the line the lap is timed across, and every distance in
  // this config is measured from it.
  finishRole: "finish",

  // Where the circuit itself puts its timing line, from the same document the
  // sector distances come from. The relation's `start` node stands 297 m away.
  timingLine: { lat: 30.1335278, lon: -97.6422583, within: 10 },

  // The circuit's own track sector map gives the centreline as 217,135 in,
  // 5,515 m. OpenStreetMap's ways come to 5,502 m, so the lap is stretched to
  // the published length rather than the lines moved, as Le Mans's is to Al
  // Kamel's.
  lapLength: 5515.0,

  // Where the sector map puts the lines the lap is timed to, measured along
  // the centreline; they add up to the published length exactly. One map
  // serves every season here, so it is written into the geometry as `sectors`
  // and the drawing places its cars between them. `Motorsport.Circuit.timingMap`
  // authors these same figures for the timing report, which reads no JSON, and
  // `app/tests/circuit-timing-map.spec.ts` fails them apart. The drawing is
  // checked against the published lap length and not against these.
  sectors: {
    kind: "published",
    source: "the circuit's own track sector map",
    stretches: [1313.2, 2254.3, 1947.5],
  },

  geojson: "app/static/geometry/cota.geojson",
  script: "circuits/cota/circuit.ts",
  survey: "The Circuit of the Americas",
};
