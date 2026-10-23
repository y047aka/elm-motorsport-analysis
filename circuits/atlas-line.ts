// The track-atlas line as this repository reads it: the shape checks that turn
// an atlas feature into a line, a place or a fraction of a lap; the guards a
// foreign file passes before it is kept as one circuit's evidence; and the file
// it is written back into. `atlas-geometry.ts` is the command — it asks, keeps
// and prints; everything below opens nothing, which is what lets a guard be
// tested against a file that was never fetched. The kept geometry those guards
// are measured against is `geometry-file.ts`'s reading, shared with every
// other reader of a served file.
//
// The atlas data is © its contributors under the ODbL, itself derived from
// OpenStreetMap and open orthoimagery.

import type { Circuit, Place } from "./circuit-geometry.ts";
import { apart, onEarth, roundTenth } from "./circuit-geometry.ts";

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

// How far an atlas file's first point may stand from the published timing line
// before the lap is judged to start somewhere else. A file that started at some
// other line would shift every marker by the distance between them while still
// looking like a lap — the same mistake `circuit-geometry.ts` guards against
// when it checks a relation's finish node.
const originWithin = 25;

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

/** How far the atlas lap's first point stands from the published timing line,
 * and the failure when that is further than the lap may start elsewhere. A
 * circuit that publishes no line goes unchecked, and says so with nought. */
export function checkOrigin(first: Place, timingLine?: Place & { within?: number }): number {
  const distance = timingLine ? apart(first, timingLine) : 0;
  if (timingLine && distance > originWithin) {
    throw new Error(
      `the atlas lap starts ${distance.toFixed(1)} m from the published timing line, ` +
        `which is more than ${originWithin} m — its markers would be measured from the wrong line`,
    );
  }
  return distance;
}

/** The atlas line in this repository's own profile, at its own length: it does
 * not end at the published lap length, and it is written not to pretend
 * otherwise — `stretched: false` says so at the properties a reader sees
 * first. Keeping it anywhere is `atlas-geometry.ts`'s. */
export function atlasFileText(
  circuit: Circuit,
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
        circuit: circuit.slug,
        basis: "measured-midline",
        source: circuit.atlas!.url,
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
