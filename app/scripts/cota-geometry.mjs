// Writes `Motorsport.Wec.Circuit.Cota.Geometry`: the Circuit of the Americas'
// centreline and pit lane, out of OpenStreetMap's relation for the circuit. The
// pipeline itself is `circuit-geometry.mjs`, which every circuit's script runs.
//
//     node scripts/cota-geometry.mjs [overpass.json]
//
// Asks OpenStreetMap, which answers a busy runner with a 502 or a 504: repeat
// the run. The answer a module should be written from can be handed in as a
// file instead. A survey that moved moves every tracker baseline, and the
// visual tests only notice metres, so read a regeneration's diff.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// module written here is a derivative of it.

import { isEntry, main } from "./circuit-geometry.mjs";

export const circuit = {
  relation: 6537729,

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

  module: "Motorsport.Wec.Circuit.Cota.Geometry",
  path: "package/src/Motorsport/Wec/Circuit/Cota/Geometry.elm",
  layout: "Motorsport.Wec.Circuit.Cota.Layout",
  script: "app/scripts/cota-geometry.mjs",
  survey: "The Circuit of the Americas",

  centrelineDoc: `The racing lap from the finish line, counter-clockwise, back to the finish
line. \`metres\` is how far round the lap a point is, stretched to the 5,515 m of
the circuit's own sector map. A sample read back off the line is stretched with
it, which is the scale the timing feed counts lap distances in.`,

  pitLaneDoc: `From where it leaves the lap 382 m before the finish line to where it merges
with it again 631 m after, in the direction it is driven. OpenStreetMap draws
the carriageway end to end, which reaches past the painted lines the sector map
puts at 116 m before the finish line and 390 m after it.`,
};

if (isEntry(import.meta.url)) {
  await main(circuit, process.argv.slice(2));
}
