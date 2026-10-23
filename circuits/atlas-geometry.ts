// Reads one circuit's measured line out of the track-atlas dataset — its
// outline's edges are measured off orthoimagery registered to lidar, with
// OpenStreetMap's centreline fixing the lap order, origin and direction — and
// keeps it in this repository's geometry profile, at the atlas length and
// *not* stretched.
//
//     node circuits/atlas-geometry.ts <circuit> [--file gp.geojson]
//
// A circuit joins these readings by carrying an `atlas` entry naming the
// track-atlas layer for the layout this app draws; `registry.ts` is where
// circuits are listed. It prints
// the four readings that matter before anyone draws on them: how far the lines
// stand apart in metres; whether the atlas corner markers land at the lap
// distances this app's geometry puts them at; whether the atlas pit entry and
// exit stand on the pit lane that geometry chains out of the relation; and
// where the circuit's own published sector lines stand on each of the two
// lines.
//
// The lap-origin guard in `atlas-line.ts` is the same check
// `circuit-geometry.ts` makes of a relation's finish node: a file that started
// at some other line would shift every marker by the distance between them
// while still looking like a lap.
// For a circuit this repository has not surveyed yet, the atlas's
// `start_finish` point is a surveyed coordinate to seed a circuit script's
// `timingLine` with; whether the lines the times are read against stand where
// the seeded line puts them is `check-timing-lines.ts`'s to answer, once a
// round has been loaded.
//
// The apartness math is `geometry-diff.ts`'s, shared with the tool that
// compares any two kept geometries; the feature shape checks, the guards and
// the written file are `atlas-line.ts`'s, shared with nothing but the tests.
// This file adds only the measuring: what is specific to laying one circuit's
// atlas line against the geometry this app draws.
//
// The atlas data is © its contributors under the ODbL, itself derived from
// OpenStreetMap and open orthoimagery; the written file carries the source URL
// beside the license.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

import type { Circuit, Sectors } from "./circuit-geometry.ts";
import { cumulative, onEarth, projection, reason, repoDir, sectorLines } from "./circuit-geometry.ts";
import type { Apartness } from "./geometry-diff.ts";
import { apartness, interpolate, nearestOn } from "./geometry-diff.ts";
import type { AtlasFeature, AtlasFile } from "./atlas-line.ts";
import {
  atlasFileText,
  checkIdentity,
  checkOrigin,
  lineOf,
  markerOf,
  placeOf,
  readKeptGeometry,
  signed,
} from "./atlas-line.ts";
import { circuits, keptAtlas } from "./registry.ts";

// How often the line is sampled for the apartness reading — corners sit tens of
// metres apart and the deviation is a slow wave along the lap.
const every = 25;

const [slug, ...argv] = process.argv.slice(2);
try {
  await run(slug, argv);
} catch (error) {
  console.error(reason(error));
  process.exitCode = 1;
}

async function run(slug: string, argv: string[]): Promise<void> {
  const circuit = circuits[slug];
  if (!circuit) throw new Error(`no circuit is surveyed under '${slug}': known are ${Object.keys(circuits).join(", ")}`);
  if (!circuit.atlas) throw new Error(`${slug}'s config names no atlas layer to read`);

  const at = argv.indexOf("--file");
  const file = at === -1 ? null : argv[at + 1];
  const theirs: AtlasFile = file ? JSON.parse(await readFile(file, "utf8")) : await ask(circuit.atlas.url);

  const features: AtlasFeature[] = theirs.features ?? [];
  const outline = features.find((f) => f.properties?.role === "outline");
  if (!outline) throw new Error("the atlas file holds no outline feature");
  checkIdentity(outline.properties.circuit, circuit.slug);
  const corners = features.filter((f) => f.properties?.role === "corner");
  const pits = ["pit_entry", "pit_exit"]
    .map((role) => features.find((f) => f.properties?.role === role))
    .filter((f): f is AtlasFeature => f !== undefined);

  const coords = lineOf(outline);

  const ours = readKeptGeometry(await readFile(join(repoDir, circuit.geojson), "utf8"), circuit.slug);
  const { project } = projection([
    ...coords.map(onEarth),
    ...ours.coords.map(onEarth),
    ...ours.pit.map(onEarth),
    ...corners.map(placeOf),
    ...pits.map(placeOf),
  ]);
  const theirPoints = coords.map(onEarth).map(project);
  const ourPoints = ours.coords.map(onEarth).map(project);
  const theirMetres = cumulative(theirPoints);
  const length = theirMetres[theirMetres.length - 1];

  const originDistance = checkOrigin(onEarth(coords[0]), circuit.timingLine);

  const deviation = apartness(theirPoints, theirMetres, ourPoints, ours.metres, every);
  const atCorners = corners.map((c) => {
    const near = nearestOn(project(placeOf(c)), ourPoints, ours.metres);
    return {
      id: c.properties.id,
      theirMetres: markerOf(c) * length,
      ourMetres: near.metres,
      distance: near.distance,
    };
  });
  const published = ours.props.sectors;
  const atLines = (published ? sectorLines(published, circuit.lapLength) : []).map((line) => {
    const near = nearestOn(interpolate(ourPoints, ours.metres, line.metres), theirPoints, theirMetres);
    return { ...line, theirMetres: near.metres, distance: near.distance };
  });

  const pitPoints = ours.pit.map(onEarth).map(project);
  const pitMetres = cumulative(pitPoints);
  const atPits = pits.map((p) => {
    const near = nearestOn(project(placeOf(p)), pitPoints, pitMetres);
    return {
      role: p.properties.role,
      theirMetres: markerOf(p) * length,
      along: near.metres,
      distance: near.distance,
    };
  });

  await keep(circuit, coords, corners, pits, theirMetres);
  print(circuit, {
    every,
    length,
    originDistance,
    deviation,
    atCorners,
    atPits,
    pitLength: pitMetres[pitMetres.length - 1],
    atLines,
    sectors: ours.props.sectors ?? null,
  });
}

function ask(url: string): Promise<AtlasFile> {
  return fetch(url, { headers: { "User-Agent": "elm-motorsport-analysis/1.0 (atlas geometry)" } })
    .then((r) => {
      if (!r.ok) throw new Error(`the atlas answered ${r.status} for ${url}`);
      return r.text();
    })
    .then(JSON.parse);
}

// Where a reading lands, and the only side effect of a run: the file itself.
// What its bytes say is `atlas-line.ts`'s `atlasFileText`.
async function keep(
  circuit: Circuit,
  coords: [number, number][],
  corners: AtlasFeature[],
  pits: AtlasFeature[],
  theirMetres: number[],
): Promise<void> {
  const path = keptAtlas(circuit);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, atlasFileText(circuit, coords, corners, pits, theirMetres));
}

/** What the reading prints: the apartness of the two lines, and where each
 * atlas marker — a corner, a pit, a published line — stands on this app's
 * line. */
type Reading = {
  every: number;
  length: number;
  originDistance: number;
  deviation: Apartness;
  atCorners: { id: string | undefined; theirMetres: number; ourMetres: number; distance: number }[];
  atPits: { role: string | undefined; theirMetres: number; along: number; distance: number }[];
  pitLength: number;
  atLines: { id: string; metres: number; theirMetres: number; distance: number }[];
  sectors: Sectors | null;
};

function print(circuit: Circuit, { every, length, originDistance, deviation, atCorners, atPits, pitLength, atLines, sectors }: Reading): void {
  const mean = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;
  const distances = atCorners.map((c) => c.distance);
  const laps = atCorners.map((c) => c.ourMetres - c.theirMetres);
  const worstLap = laps.reduce((a, b) => (Math.abs(b) > Math.abs(a) ? b : a), 0);
  console.log(`== ${circuit.slug}: the atlas line against the geometry this app draws`);
  console.log(
    `length: measured ${length.toFixed(1)} m against the published ${circuit.lapLength} m ` +
      `(${signed(length - circuit.lapLength)}); ` +
      (circuit.timingLine
        ? `the lap starts ${originDistance.toFixed(1)} m from the published timing line`
        : "the circuit script names no timing line, so the atlas lap's start goes unchecked"),
  );
  console.log(
    `lines sampled every ${every} m (${deviation.count}): mean apart ${deviation.mean.toFixed(1)} m, ` +
      `max ${deviation.worst.distance.toFixed(1)} m at their ${deviation.worst.aMetres.toFixed(0)} m, our ${deviation.worst.bMetres.toFixed(1)} m`,
  );
  console.log(
    `corners (${atCorners.length}): mean apart ${mean(distances).toFixed(1)} m, max ${Math.max(...distances).toFixed(1)} m; ` +
      `lap distance differs by ${mean(laps.map(Math.abs)).toFixed(1)} m on average, worst ${signed(worstLap)} m`,
  );
  for (const c of atCorners) {
    console.log(
      `  ${c.id}: marker at ${c.theirMetres.toFixed(1)} m, our line has that place at ` +
        `${c.ourMetres.toFixed(1)} m (${signed(c.ourMetres - c.theirMetres)}), ${c.distance.toFixed(1)} m apart`,
    );
  }
  if (atPits.length > 0) {
    console.log(`pit markers (${atPits.length}), against our own pit lane of ${pitLength.toFixed(1)} m:`);
    for (const p of atPits) {
      console.log(
        `  ${p.role}: the atlas stands it at lap ${p.theirMetres.toFixed(1)} m; ` +
          `${p.distance.toFixed(1)} m from our pit lane, ${p.along.toFixed(1)} m along it`,
      );
    }
  }
  if (atLines.length > 0 && sectors !== null) {
    console.log(`the lines ${sectors.source} publishes, on each line:`);
    for (const l of atLines) {
      console.log(
        `  ${l.id} begins at our ${l.metres.toFixed(1)} m; the atlas line has that place at ` +
          `${l.theirMetres.toFixed(1)} m (${signed(l.theirMetres - l.metres)}), ${l.distance.toFixed(1)} m apart`,
      );
    }
  }
}
