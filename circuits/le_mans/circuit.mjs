// The Circuit de la Sarthe's config for the geometry pipeline: the relation to
// survey, the figures the circuit publishes, and the word its rounds are known
// by. What the pipeline writes and how is `circuit-geometry.mjs`; where these
// figures come from and what holds them is `circuits/README.md`.
//
//     node circuits/le_mans/circuit.mjs [overpass.json]
//     node circuits/le_mans/circuit.mjs --from-geojson [geometry.json]
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// geometry written here is a derivative of it.

import { isEntry, main } from "../circuit-geometry.mjs";

export const circuit = {
  relation: 2126739,

  // The word `Motorsport.Circuit.jsonValue` sends for Le Mans, which names the
  // served file.
  slug: "le_mans",

  // The relation tags one node `start-finish`, which is where Al Kamel
  // measures from and so where the lap's zero stands.
  finishRole: "start-finish",

  // Al Kamel's circuit maps give the centreline as 13,625.7 m every season
  // from 2024 to 2026, and every distance the timing lines are placed at is
  // measured along it. OpenStreetMap's ways come to a little less, so the lap
  // is stretched to the published length rather than the lines moved.
  lapLength: 13625.7,

  geojson: "app/static/geometry/le_mans.geojson",
  script: "circuits/le_mans/circuit.mjs",
  survey: "The Circuit de la Sarthe",
};

if (isEntry(import.meta.url)) {
  await main(circuit, process.argv.slice(2));
}
