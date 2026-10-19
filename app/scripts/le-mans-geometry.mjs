// Writes `Motorsport.Wec.Circuit.LeMans.Geometry`: the Circuit de la Sarthe's
// centreline and pit lane, out of OpenStreetMap's relation for the circuit. The
// pipeline itself is `circuit-geometry.mjs`, which every circuit's script runs.
//
//     node scripts/le-mans-geometry.mjs [overpass.json]
//     node scripts/le-mans-geometry.mjs --from-geojson [geometry.json]
//
// Asks OpenStreetMap, which answers a busy runner with a 502 or a 504: repeat
// the run. The answer a module should be written from can be handed in as a
// file instead. Either way the geometry lands beside these scripts, as
// `geometry/le-mans.geojson`; `--from-geojson` writes the module from that with
// no OpenStreetMap, which is how a regeneration is shown to have changed
// nothing. A survey that moved moves every tracker baseline, and the visual
// tests only notice metres, so read a regeneration's diff.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// module written here is a derivative of it.

import { isEntry, main } from "./circuit-geometry.mjs";

export const circuit = {
  relation: 2126739,
  slug: "le-mans",

  // The relation tags one node `start-finish`, which is where Al Kamel measures
  // from and so where the lap's zero stands.
  finishRole: "start-finish",

  // Al Kamel's circuit maps give the centreline as 13,625.7 m every season from
  // 2024 to 2026, and every distance the timing lines are placed at is measured
  // along it. OpenStreetMap's ways come to a little less, so the lap is stretched
  // to the published length rather than the lines moved.
  lapLength: 13625.7,

  module: "Motorsport.Wec.Circuit.LeMans.Geometry",
  path: "package/src/Motorsport/Wec/Circuit/LeMans/Geometry.elm",
  geojson: "app/scripts/geometry/le-mans.geojson",
  layout: "Motorsport.Wec.Circuit.LeMans.Layout",
  script: "app/scripts/le-mans-geometry.mjs",
  survey: "The Circuit de la Sarthe",

  centrelineDoc: `The racing lap from the finish line, clockwise, back to the finish line.
\`metres\` is how far round the lap a point is, stretched to the 13,625.7 m of
Al Kamel's circuit maps. A sample read back off the line is stretched with it,
which is the scale the timing feed counts lap distances in.`,

  pitLaneDoc: `From where it leaves the track before the Ford chicane to where it rejoins
it in the Dunlop curve, in the direction it is driven.`,
};

if (isEntry(import.meta.url)) {
  await main(circuit, process.argv.slice(2));
}
