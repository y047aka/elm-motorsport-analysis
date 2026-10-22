// Reads one circuit's measured line out of the track-atlas dataset — its
// outline's edges are measured off orthoimagery registered to lidar, with
// OpenStreetMap's centreline fixing the lap order, origin and direction — and
// keeps it in this repository's geometry profile, at the atlas length and
// *not* stretched.
//
//     node circuits/atlas-geometry.mjs <circuit> [--file gp.geojson]
//
// A circuit joins the `atlas` table below by one entry naming the script that
// surveys it and the atlas outline for the layout this app draws. It prints
// the four readings that matter before anyone draws on them: how far the lines
// stand apart in metres; whether the atlas corner markers land at the lap
// distances this app's geometry puts them at; whether the atlas pit entry and
// exit stand on the pit lane that geometry chains out of the relation; and
// where the circuit's own published sector lines stand on each of the two
// lines.
//
// The lap-origin guard below is the same check `circuit-geometry.mjs` makes of
// a relation's finish node: a file that started at some other line would shift
// every marker by the distance between them while still looking like a lap.
// For a circuit this repository has not surveyed yet, the atlas's
// `start_finish` point is a surveyed coordinate to seed a circuit script's
// `timingLine` with; whether the lines the times are read against stand where
// the seeded line puts them is `check-timing-lines.mjs`'s to answer, once a
// round has been loaded.
//
// The apartness math is `geometry-diff.mjs`'s, shared with the tool that
// compares any two kept geometries; this file adds only what is specific to
// taking a foreign dataset in.
//
// The atlas data is © its contributors under the ODbL, itself derived from
// OpenStreetMap and open orthoimagery; the written file carries the source URL
// beside the license.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { cumulative, degreesToMetres, projection } from "./circuit-geometry.mjs";
import { apartness, interpolate, nearestOn } from "./geometry-diff.mjs";

const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const atlas = {
  // Keyed by the circuit word, the slug its script holds. `script` is the one
  // that surveys it; the reading lands in the circuit's own directory rather
  // than in `static/` — it is evidence a decision is judged on, never bytes
  // the app asks for. `originWithin` is how far the file's first point may
  // stand from the published timing line before the lap is judged to start
  // somewhere else. `every` is how often the line is sampled for the
  // apartness reading — corners sit tens of metres apart and the deviation is
  // a slow wave along the lap.
  cota: {
    script: "./cota/circuit.mjs",
    url: "https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-of-the-americas/raw/layers/gp.geojson",
    out: "circuits/cota/atlas.geojson",
    originWithin: 25,
    every: 25,
  },
  le_mans: {
    script: "./le_mans/circuit.mjs",
    url: "https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-de-la-sarthe/raw/layers/24h.geojson",
    out: "circuits/le_mans/atlas.geojson",
    originWithin: 25,
    every: 25,
  },
};

const [slug, ...argv] = process.argv.slice(2);
try {
  await run(slug, argv);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

async function run(slug, argv) {
  const entry = atlas[slug];
  if (!entry) throw new Error(`no atlas line is registered for '${slug}': known are ${Object.keys(atlas).join(", ")}`);
  const { circuit } = await import(entry.script);

  const at = argv.indexOf("--file");
  const file = at === -1 ? null : argv[at + 1];
  const theirs = file ? JSON.parse(await readFile(file, "utf8")) : await ask(entry.url);

  const outline = (theirs.features ?? []).find((f) => f.properties?.role === "outline");
  if (!outline) throw new Error("the atlas file holds no outline feature");
  const corners = theirs.features.filter((f) => f.properties?.role === "corner");
  const pits = ["pit_entry", "pit_exit"]
    .map((role) => theirs.features.find((f) => f.properties?.role === role))
    .filter((f) => f !== undefined);

  const ours = readKeptGeometry(await readFile(join(repoDir, circuit.geojson), "utf8"));
  const earth = ([lon, lat]) => ({ lat, lon });
  const { project } = projection(
    [
      ...outline.geometry.coordinates,
      ...ours.coords,
      ...ours.pit,
      ...corners.map((c) => c.geometry.coordinates),
      ...pits.map((p) => p.geometry.coordinates),
    ].map(earth),
  );
  const theirPoints = outline.geometry.coordinates.map(earth).map(project);
  const ourPoints = ours.coords.map(earth).map(project);
  const theirMetres = cumulative(theirPoints);
  const length = theirMetres[theirMetres.length - 1];

  const originDistance = toPublished(outline.geometry.coordinates[0], circuit.timingLine);
  if (circuit.timingLine && originDistance > entry.originWithin) {
    throw new Error(
      `the atlas lap starts ${originDistance.toFixed(1)} m from the published timing line, ` +
        `which is more than ${entry.originWithin} m — its markers would be measured from the wrong line`,
    );
  }

  const apart = apartness(theirPoints, theirMetres, ourPoints, ours.metres, entry.every);
  const atCorners = corners.map((c) => {
    const near = nearestOn(project(earth(c.geometry.coordinates)), ourPoints, ours.metres);
    return {
      id: c.properties.id,
      theirMetres: c.properties.marker * length,
      ourMetres: near.metres,
      distance: near.distance,
    };
  });
  const atLines = sectorLines(ours.props.sectors).map((line) => {
    const near = nearestOn(interpolate(ourPoints, ours.metres, line.metres), theirPoints, theirMetres);
    return { ...line, theirMetres: near.metres, distance: near.distance };
  });

  const pitPoints = ours.pit.map(earth).map(project);
  const pitMetres = cumulative(pitPoints);
  const atPits = pits.map((p) => {
    const near = nearestOn(project(earth(p.geometry.coordinates)), pitPoints, pitMetres);
    return {
      role: p.properties.role,
      theirMetres: p.properties.marker * length,
      along: near.metres,
      distance: near.distance,
    };
  });

  await writeAtlasGeometry(entry.out, slug, entry.url, outline, corners, pits, theirMetres);
  print(slug, circuit, {
    every: entry.every,
    length,
    originDistance,
    apart,
    atCorners,
    atPits,
    pitLength: pitMetres[pitMetres.length - 1],
    atLines,
    sectors: ours.props.sectors,
  });
}

// The lines the circuit's own map publishes, as positions round the lap: each
// stretch ends where the next begins, and the last ends at the line the lap is
// measured from — which is where it started, so it is not a line to place.
function sectorLines(sectors) {
  if (!sectors) return [];
  const names = ["s2", "s3", "s4"];
  const lines = [];
  let at = 0;
  for (const [index, stretch] of sectors.stretches.entries()) {
    at += stretch;
    if (index < sectors.stretches.length - 1) lines.push({ id: names[index], metres: at });
  }
  return lines;
}

// Distance on the ground between a surveyed degree pair and the line the
// circuit publishes for its lap zero — the same equirectangular measure a
// relation's finish node is checked with.
function toPublished([lon, lat], published) {
  if (!published) return 0;
  return Math.hypot(
    (lat - published.lat) * degreesToMetres,
    (lon - published.lon) * degreesToMetres * Math.cos((lat * Math.PI) / 180),
  );
}

function ask(url) {
  return fetch(url, { headers: { "User-Agent": "elm-motorsport-analysis/1.0 (atlas geometry)" } })
    .then((r) => {
      if (!r.ok) throw new Error(`the atlas answered ${r.status} for ${url}`);
      return r.text();
    })
    .then(JSON.parse);
}

function readKeptGeometry(text) {
  const json = JSON.parse(text);
  const outline = json.features.find((f) => f.properties?.role === "outline");
  const pit = json.features.find((f) => f.properties?.role === "pit_lane");
  if (!outline || !pit) throw new Error("the kept geometry holds no outline or no pit lane");
  const { metres, ...props } = outline.properties;
  return { coords: outline.geometry.coordinates, metres, props, pit: pit.geometry.coordinates };
}

// The atlas line in this repository's own profile, at its own length: a reader
// that later hands it to the module generator is told it does not end at the
// published lap length, because it was written not to pretend otherwise.
async function writeAtlasGeometry(out, slug, url, outline, corners, pits, theirMetres) {
  const length = theirMetres[theirMetres.length - 1];
  const features = [
    {
      type: "Feature",
      properties: {
        role: "outline",
        circuit: slug,
        basis: "measured-midline",
        source: url,
        license: "ODbL",
        lap_length_m: round1(length),
        stretched: false,
        metres: theirMetres.map(round1),
      },
      geometry: { type: "LineString", coordinates: outline.geometry.coordinates },
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
  const path = join(repoDir, out);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `{"type": "FeatureCollection", "features": [\n${body}\n]}\n`);
}

function print(slug, circuit, { every, length, originDistance, apart, atCorners, atPits, pitLength, atLines, sectors }) {
  const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;
  const distances = atCorners.map((c) => c.distance);
  const laps = atCorners.map((c) => c.ourMetres - c.theirMetres);
  const worstLap = laps.reduce((a, b) => (Math.abs(b) > Math.abs(a) ? b : a), 0);
  console.log(`== ${slug}: the atlas line against the geometry this app draws`);
  console.log(
    `length: measured ${length.toFixed(1)} m against the published ${circuit.lapLength} m ` +
      `(${signed(length - circuit.lapLength)}); ` +
      (circuit.timingLine
        ? `the lap starts ${originDistance.toFixed(1)} m from the published timing line`
        : "the circuit script names no timing line, so the atlas lap's start goes unchecked"),
  );
  console.log(
    `lines sampled every ${every} m (${apart.count}): mean apart ${apart.mean.toFixed(1)} m, ` +
      `max ${apart.worst.distance.toFixed(1)} m at their ${apart.worst.aMetres.toFixed(0)} m, our ${apart.worst.bMetres.toFixed(1)} m`,
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
  if (atLines.length > 0) {
    console.log(`the lines ${sectors.source} publishes, on each line:`);
    for (const l of atLines) {
      console.log(
        `  ${l.id} begins at our ${l.metres.toFixed(1)} m; the atlas line has that place at ` +
          `${l.theirMetres.toFixed(1)} m (${signed(l.theirMetres - l.metres)}), ${l.distance.toFixed(1)} m apart`,
      );
    }
  }
}

function round1(n) {
  return Math.round(n * 10) / 10;
}

function signed(n) {
  return `${n >= 0 ? "+" : ""}${n.toFixed(1)}`;
}
