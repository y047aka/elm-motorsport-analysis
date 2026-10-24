// Writes a circuit's geometry, or checks the kept one, for whichever circuit
// the registry knows it as:
//
//     node circuits/write-geometry.ts <circuit> [overpass.json]
//     node circuits/write-geometry.ts <circuit> --from-geojson [geometry.json]
//
// One command for every circuit because the registry is what knows circuits; a
// flake app per circuit would make a new survey a new registration too. The
// pipeline it runs is `circuit-geometry.ts`, and `main` there is where the
// flags mean what they say. `nix run .#geometry-write` is the Flix pipeline
// now; this script is what still answers `--from-geojson`, the re-check of a
// kept geometry against its circuit's own claims that the Flix survey does not
// answer yet.

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
