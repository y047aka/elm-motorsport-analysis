// Writes a circuit's geometry, or checks the kept one, for whichever circuit
// the registry knows it as:
//
//     node circuits/write-geometry.ts <circuit> [overpass.json]
//     node circuits/write-geometry.ts <circuit> --from-geojson [geometry.json]
//
// One command for every circuit because the registry is what knows circuits; a
// flake app per circuit would make a new survey a new registration too. Given
// an Overpass answer as a file, reads it rather than asking. `--from-geojson`
// writes nothing: it runs the checks the app's runtime decoder will run, over
// the kept geometry and with no OpenStreetMap.

import { main } from "./circuit-geometry.ts";
import { circuits } from "./registry.ts";

const [slug, ...argv] = process.argv.slice(2);
const circuit = circuits[slug];
if (!circuit) {
  console.error(`no circuit is surveyed under '${slug}': known are ${Object.keys(circuits).join(", ")}`);
  process.exitCode = 1;
} else {
  await main(circuit, argv);
}
