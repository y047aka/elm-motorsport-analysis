// The Circuit de la Sarthe's config for the geometry pipeline: the relation to
// survey, the figures the circuit publishes, and the word its rounds are known
// by. What the pipeline writes and how, and where these figures come from and
// what holds them, is `circuits/README.md`.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// geometry written here is a derivative of it.

import type { Circuit } from "../circuit-geometry.ts";

export const circuit: Circuit = {
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

  // The lines are copied from Al Kamel's map of each year and differ between
  // them by design, so no one set answers for two seasons — which is why
  // `nix run .#geometry-timing-lines` refuses a round here and quotes this
  // reason doing it; `Motorsport.Circuit.timingMap` holds the same one. The maps
  // are not to be redistributed, so nothing here holds their figures; the
  // season's own `Layout` module is where its line placements live.
  sectors: {
    kind: "perSeason",
    reason: "the organiser's map is re-issued every year and its lines differ between seasons",
  },

  geojson: "app/static/geometry/le_mans.geojson",
  script: "circuits/le_mans/circuit.ts",
  survey: "The Circuit de la Sarthe",
};
