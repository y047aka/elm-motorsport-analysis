// The circuits this repository has surveyed, keyed by the word the app draws
// them by, and where a circuit's kept files stand beside the config that
// surveyed it. Every tool that iterates circuits or reaches one by that word
// imports them from here rather than keeping its own table: the config in
// `<circuit>/circuit.ts` is where a circuit's figures are authored, so a new
// survey is one config and one line here, and nothing downstream has to be
// told twice.
//
// It sits beside the pipeline rather than in it: `circuit-geometry.ts` works
// on whichever config it is handed and names no circuit.

import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import type { Circuit } from "./circuit-geometry.ts";
import { circuit as cota } from "./cota/circuit.ts";
import { circuit as leMans } from "./le_mans/circuit.ts";

export const circuits: Record<string, Circuit> = { cota, le_mans: leMans };

const circuitsDir = dirname(fileURLToPath(import.meta.url));

/** The Overpass answer a kept geometry was drawn from, kept beside the config
 * that surveyed it — evidence the regeneration fence reads, never bytes the
 * app asks for. */
export const keptAnswer = (circuit: Circuit): string => join(circuitsDir, circuit.slug, "overpass.json");

/** Where a circuit's atlas line lands once measured: beside the survey it is
 * judged against, not in what gets served. */
export const keptAtlas = (circuit: Circuit): string => join(circuitsDir, circuit.slug, "atlas.geojson");
