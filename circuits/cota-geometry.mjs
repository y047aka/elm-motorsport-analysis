// Writes the Circuit of the Americas' geometry: its centreline and pit lane,
// out of OpenStreetMap's relation for the circuit, as the served file the
// tracker decodes at runtime. The pipeline itself is `circuit-geometry.mjs`,
// which every circuit's script runs.
//
//     node circuits/cota-geometry.mjs [overpass.json]
//     node circuits/cota-geometry.mjs --from-geojson [geometry.json]
//
// Asks OpenStreetMap, which answers a busy runner with a 502 or a 504: repeat
// the run. The answer a geometry should be written from can be handed in as a
// file instead. Either way the geometry lands where the app serves it, as
// `static/geometry/cota.geojson`; `--from-geojson` checks the kept file against
// this config with no OpenStreetMap. A survey that moved moves every tracker
// baseline, and the visual tests only notice metres, so read a regeneration's
// diff.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// geometry written here is a derivative of it.

import { isEntry, main } from "./circuit-geometry.mjs";

export const circuit = {
  relation: 6537729,
  slug: "cota",

  // The relation tags two nodes, `start` and `finish`, 297 m apart along the
  // lap: the first is where the race starts and the second is the line the lap is
  // timed across, which is the one every distance below is measured from.
  finishRole: "finish",

  // Where the circuit itself puts its finish and timing line, from the same
  // document the sector distances come from. The relation's `start` node is 297
  // m from it.
  timingLine: { lat: 30.1335278, lon: -97.6422583, within: 10 },

  // The circuit's own track sector map gives the centreline as 217,135 in,
  // 5,515 m, and measures its three intermediate sectors along it -- 1,313.2,
  // 2,254.3 and 1,947.5 m, which add up to exactly that. OpenStreetMap's ways
  // come to 5,502 m, so the lap is stretched to the published length rather
  // than the lines moved, as Le Mans's is to Al Kamel's.
  lapLength: 5515.0,

  // Where the sector map puts the lines the lap is timed to, measured along it
  // -- the same distances `Motorsport.Wec.Circuit.Cota.Layout` places, written
  // into the geometry as `sectors` so `check-timing-lines.mjs` reads the
  // geometry file rather than this script. The drawing is checked against the
  // published lap length and not against these; a line moved in one and not the
  // other is a drift to read as a diff, as a regeneration is.
  sectorMapStretches: [1313.2, 2254.3, 1947.5],
  sectorsSource: "the circuit's own track sector map",

  geojson: "app/static/geometry/cota.geojson",
  script: "circuits/cota-geometry.mjs",
  survey: "The Circuit of the Americas",
};

if (isEntry(import.meta.url)) {
  await main(circuit, process.argv.slice(2));
}
