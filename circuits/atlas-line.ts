// The track-atlas line as this repository reads it: the shape checks that turn
// an atlas feature into a line, a place or a fraction of a lap; the guard a
// foreign file passes before it is kept as one circuit's evidence; and the file
// it is written back into. `atlas-geometry.ts` is the command — it asks, keeps
// and prints; everything below opens nothing, which is what lets a guard be
// tested against a file that was never fetched. The kept geometry the guard is
// measured against is `geometry-file.ts`'s reading, shared with every other
// reader of a served file, and the lap-origin guard is `timing-line.ts`'s —
// the question the pipeline asks of a relation's finish node too.
//
// The atlas data is © its contributors under the ODbL, itself derived from
// OpenStreetMap and open orthoimagery.

import type { Place } from "./circuit-geometry.ts";
import { onEarth, roundTenth } from "./circuit-geometry.ts";

/** One feature of a track-atlas layer: its role, and what that role's own
 * properties say. Corner and pit markers place themselves along the lap with
 * a `marker` — a fraction of it, not a metre. */
export type AtlasFeature = {
  properties: {
    role?: string;
    circuit?: string;
    id?: string;
    name?: string;
    marker?: number;
    direction?: string;
  };
  geometry?: { type?: string; coordinates?: unknown };
};

export type AtlasFile = { features?: AtlasFeature[] };

/** An atlas outline as the line it measures: degrees, lon before lat. */
export function lineOf(feature: AtlasFeature): [number, number][] {
  const coordinates = feature.geometry?.coordinates;
  if (!Array.isArray(coordinates) || !Array.isArray(coordinates[0]) || coordinates.length < 2) {
    throw new Error("the atlas outline holds no line to measure");
  }
  return coordinates as [number, number][];
}

/** An atlas point feature — a corner or a pit marker — as the place it
 * stands at: a Point's coordinates are that pair itself, not a list of
 * them, unlike the outline's LineString. */
export function placeOf(feature: AtlasFeature): Place {
  const coordinates = feature.geometry?.coordinates;
  if (!Array.isArray(coordinates) || coordinates.length !== 2 || typeof coordinates[0] !== "number") {
    throw new Error(`the atlas ${feature.properties.role ?? "feature"} carries no point`);
  }
  return onEarth(coordinates as [number, number]);
}

/** Where on the lap a corner or pit marker stands, as the atlas's fraction of
 * it. A feature with no marker would otherwise be measured at `NaN m` rather
 * than fail by name. */
export function markerOf(feature: AtlasFeature): number {
  const marker = feature.properties.marker;
  if (typeof marker !== "number" || !Number.isFinite(marker)) {
    throw new Error(`the atlas ${feature.properties.role ?? "feature"} carries no marker`);
  }
  return marker;
}

/** The reading is kept under the slug given on the command line, whatever
 * the file was measured from — a mismatched pair replaces one circuit's kept
 * evidence with another circuit's line. A file that names itself not at all
 * is taken on the slug's word alone. */
export function checkIdentity(named: string | undefined, slug: string): void {
  if (named && named !== slug) {
    throw new Error(
      `the atlas file names itself '${named}', not '${slug}' — it is not this circuit's line`,
    );
  }
}

/** Whose line it is and where it was measured from — the two claims of its
 * own that the written atlas file carries, and the only two the writing
 * needs. */
export type AtlasProvenance = { slug: string; source: string };

/** The atlas line in this repository's own profile, at its own length: it does
 * not end at the published lap length, and it is written not to pretend
 * otherwise — `stretched: false` says so at the properties a reader sees
 * first. Keeping it anywhere is `atlas-geometry.ts`'s. */
export function atlasFileText(
  line: AtlasProvenance,
  coords: [number, number][],
  corners: AtlasFeature[],
  pits: AtlasFeature[],
  theirMetres: number[],
): string {
  const length = theirMetres[theirMetres.length - 1];
  const features = [
    {
      type: "Feature",
      properties: {
        role: "outline",
        circuit: line.slug,
        basis: "measured-midline",
        source: line.source,
        license: "ODbL",
        lap_length_m: roundTenth(length),
        stretched: false,
        metres: theirMetres.map(roundTenth),
      },
      geometry: { type: "LineString", coordinates: coords },
    },
    ...corners.map((c) => ({
      type: "Feature",
      properties: { role: "corner", id: c.properties.id, marker: c.properties.marker, direction: c.properties.direction },
      geometry: c.geometry,
    })),
    ...pits.map((p) => ({
      type: "Feature",
      properties: { role: p.properties.role, name: p.properties.name, marker: p.properties.marker },
      geometry: p.geometry,
    })),
  ];
  const body = features.map((f) => `    ${JSON.stringify(f)}`).join(",\n");
  return `{"type": "FeatureCollection", "features": [\n${body}\n]}\n`;
}

/** A distance shown with the sign that says which line is longer. */
export function signed(n: number): string {
  return `${n >= 0 ? "+" : ""}${n.toFixed(1)}`;
}
