// The Circuit de la Sarthe's config for the geometry pipeline: the relation to
// survey, the figures the circuit publishes, and the word its rounds are known
// by. What the pipeline writes and how is `circuit-geometry.ts`, run by
// `write-geometry.ts`; where these figures come from and what holds them is
// `circuits/README.md`.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// geometry written here is a derivative of it.

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

  // The track-atlas layer for the 24h layout — a midline measured off
  // orthoimagery, read against the survey above by `atlas-geometry.ts`.
  atlas: {
    url: "https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-de-la-sarthe/raw/layers/24h.geojson",
  },

  geojson: "app/static/geometry/le_mans.geojson",
  script: "circuits/le_mans/circuit.ts",
  survey: "The Circuit de la Sarthe",
};
