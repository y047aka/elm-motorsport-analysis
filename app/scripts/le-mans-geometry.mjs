// Writes the Circuit de la Sarthe's geometry: its centreline and pit lane, out
// of OpenStreetMap's relation for the circuit, as the served file the tracker
// decodes at runtime. The pipeline itself is `circuit-geometry.mjs`, which
// every circuit's script runs.
//
//     node scripts/le-mans-geometry.mjs [overpass.json]
//     node scripts/le-mans-geometry.mjs --from-geojson [geometry.json]
//
// Asks OpenStreetMap, which answers a busy runner with a 502 or a 504: repeat
// the run. The answer a geometry should be written from can be handed in as a
// file instead. Either way the geometry lands where the app serves it, as
// `static/geometry/le_mans.geojson`; `--from-geojson` checks the kept file
// against this config with no OpenStreetMap. A survey that moved moves every
// tracker baseline, and the visual tests only notice metres, so read a
// regeneration's diff.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// geometry written here is a derivative of it.

import { isEntry, main } from "./circuit-geometry.mjs";

export const circuit = {
  relation: 2126739,

  // The word `Motorsport.Circuit.jsonValue` sends for Le Mans, which is what
  // names the served file: the app asks for `le_mans.geojson` by that word.
  slug: "le_mans",

  // The relation tags one node `start-finish`, which is where Al Kamel measures
  // from and so where the lap's zero stands.
  finishRole: "start-finish",

  // Al Kamel's circuit maps give the centreline as 13,625.7 m every season from
  // 2024 to 2026, and every distance the timing lines are placed at is measured
  // along it. OpenStreetMap's ways come to a little less, so the lap is stretched
  // to the published length rather than the lines moved.
  lapLength: 13625.7,

  geojson: "app/static/geometry/le_mans.geojson",
  script: "app/scripts/le-mans-geometry.mjs",
  survey: "The Circuit de la Sarthe",
};

if (isEntry(import.meta.url)) {
  await main(circuit, process.argv.slice(2));
}
