// The reading of this repository's own geometry-file profile: the outline as
// the line it claims to be — its points, its own metres, the properties a
// report quotes — and the pit lane beside it. Every tool that reads a kept
// geometry file reaches these readings rather than finding features by role
// again: the pipeline's `--from-geojson` check over the kept file,
// `geometry-diff.ts` laying two lines against each other, and the atlas
// reading measuring its line against the survey. A kept file is a file of a
// stranger's too — the atlas line is one — so a failure names the file it was
// reading.
//
// What is checked here is what the profile itself claims of a line: a basis
// among the kinds its readers know, one metre per point, none of them going
// backwards, and points enough to be a line. The
// claims that belong to a circuit — that the last metre stands at *its*
// published length, that published stretches add up — are checked by the
// reader that knows the circuit, on top of this.

import type { GeometryFile, OutlineProperties } from "./circuit-geometry.ts";

/** The kinds of line a file of this profile may name as its `basis`: the
 * OpenStreetMap centreline, stretched to a published lap, and a midline
 * measured off orthoimagery at its own length. What a reader may trust a line
 * for turns on which of the two it is — one ends where the published lap says,
 * the other is not expected to — so a file naming a basis outside these is
 * either a kind of line no reader has been told about yet, or an edited file.
 * Both answer to a failure by name better than to a default that reads the
 * line like any other. */
export const lineBases = ["osm-centreline", "measured-midline"] as const;

export type LineBasis = (typeof lineBases)[number];

const isBasis = (word: string | undefined): word is LineBasis =>
  lineBases.includes(word as LineBasis);

/** One geometry laid against the others: its name, the properties a report
 * quotes, its coordinates as they stand in the file, and its own metres. */
export type KeptLine = {
  name: string;
  props: OutlineProperties;
  coords: [number, number][];
  metres: number[];
};

/** The outline of one geometry file. Coordinates are degrees, lon before lat,
 * as GeoJSON gives them; the metres leave the properties on the way through,
 * because they belong to the line and not to a report. */
export function outlineOf(json: GeometryFile, name: string): KeptLine {
  const outline = (json.features ?? []).find((f) => f.properties?.role === "outline");
  if (!outline) throw new Error(`${name}: no outline feature`);
  const basis = outline.properties?.basis;
  if (!isBasis(basis)) {
    throw new Error(
      `${name}: the outline names basis ${basis === undefined ? "nothing" : `"${basis}"`}, which is not a line this repository reads`,
    );
  }
  const coords = outline.geometry?.coordinates ?? [];
  if (coords.length === 0) throw new Error(`${name}: the outline holds no points to draw`);
  const { metres, ...props } = outline.properties ?? {};
  if (!Array.isArray(metres)) throw new Error(`${name}: the outline publishes no metres`);
  if (coords.length !== metres.length) {
    throw new Error(`${name}: ${metres.length} metres for ${coords.length} points`);
  }
  for (let at = 1; at < metres.length; at++) {
    if (metres[at] < metres[at - 1]) throw new Error(`${name}: metres go backwards at point ${at}`);
  }
  return { name, props, coords, metres };
}

/** The pit lane beside the outline: a line with no metres, because nothing
 * times along it. */
export function pitLaneOf(json: GeometryFile, name: string): [number, number][] {
  const pit = (json.features ?? []).find((f) => f.properties?.role === "pit_lane");
  if (!pit) throw new Error(`${name}: the geometry holds no pit lane`);
  const coords = pit.geometry?.coordinates;
  if (!coords) throw new Error(`${name}: the pit lane holds no coordinates`);
  return coords;
}

/** The geometry the app serves, read the way every reader of a kept file
 * reads it, from its text: the outline, its own metres, and the pit lane the
 * atlas pit markers are placed against. */
export function readKeptGeometry(text: string, name: string): KeptLine & { pit: [number, number][] } {
  const json = JSON.parse(text) as GeometryFile;
  return { ...outlineOf(json, name), pit: pitLaneOf(json, name) };
}
