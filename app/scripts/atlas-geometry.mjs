// Reads one circuit's measured line out of the track-atlas dataset, keeps it
// beside our own geometries, and says how far it stands from the line this app
// draws.
//
//     node scripts/atlas-geometry.mjs cota [--file gp.geojson]
//
// The atlas draws its outlines from orthoimagery registered to lidar, so its
// line is an independent second survey of the same ground: where our geometry
// is the OpenStreetMap centreline stretched to the circuit's published lap
// length, theirs is a measurement of the track surface at its own length. This
// writes `geometry/<circuit>.atlas.geojson` — their outline and corner markers
// in this repository's geometry profile, at their length and *not* stretched —
// and prints the two readings that matter before anyone draws on them: how far
// the lines stand apart in metres, and whether the atlas corner markers land at
// the lap distances our geometry puts its timing lines beside.
//
// It writes no Elm and no Layout. Whether to draw on a measured line instead of
// the stretched survey is a separate change, and an expensive one: every tracker
// baseline moves with it, and the timing-line placements would have to be
// re-argued against the new basis. The lap-origin guard below is the same check
// `circuit-geometry.mjs` makes of a relation's finish node — the atlas lap
// starts where the circuit says its timing line is, and a file that started at
// some other line would shift every marker by the distance between them while
// still looking like a lap.
//
// The atlas data is © its contributors under the ODbL, itself derived from
// OpenStreetMap and open orthoimagery; the written file carries the source URL
// beside the license.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { cumulative, degreesToMetres, projection } from "./circuit-geometry.mjs";
import { circuit as cota } from "./cota-geometry.mjs";

const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const atlas = {
  cota: {
    circuit: cota,
    url: "https://raw.githubusercontent.com/tobi/track-atlas/main/tracks/circuit-of-the-americas/raw/layers/gp.geojson",
    // How far the file's first point may stand from the published timing line
    // before the lap is judged to start somewhere else. The mistake this
    // catches is the one the Circuit of the Americas' relation actually makes:
    // its two tagged lines stand 297 m apart along the lap.
    originWithin: 25,
    // How often the line is sampled for the apartness reading. Corners sit tens
    // of metres apart and the deviation is a slow wave along the lap; anything
    // finer is noise on a report meant to be read at lap scale.
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
  const { circuit } = entry;

  const at = argv.indexOf("--file");
  const file = at === -1 ? null : argv[at + 1];
  const theirs = file ? JSON.parse(await readFile(file, "utf8")) : await ask(entry.url);

  const outline = (theirs.features ?? []).find((f) => f.properties?.role === "outline");
  if (!outline) throw new Error("the atlas file holds no outline feature");
  const corners = theirs.features.filter((f) => f.properties?.role === "corner");

  const ours = readKeptGeometry(await readFile(join(repoDir, circuit.geojson), "utf8"));
  const earth = ([lon, lat]) => ({ lat, lon });
  const { project } = projection([...outline.geometry.coordinates, ...ours.coords, ...corners.map((c) => c.geometry.coordinates)].map(earth));
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

  await writeAtlasGeometry(circuit, slug, entry.url, outline, corners, theirMetres);
  print(slug, circuit, entry.every, length, originDistance, apart, atCorners);
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
  const outline = JSON.parse(text).features.find((f) => f.properties?.role === "outline");
  if (!outline) throw new Error("the kept geometry holds no outline feature");
  return { coords: outline.geometry.coordinates, metres: outline.properties.metres };
}

// The two lines laid against each other: sampled every `every` metres along
// theirs, the nearest ground distance to ours and the lap distance here that
// same place falls at.
function apartness(theirPoints, theirMetres, ourPoints, ourMetres, every) {
  const length = theirMetres[theirMetres.length - 1];
  const samples = [];
  for (let s = 0; s < length; s += every) {
    const near = nearestOn(interpolate(theirPoints, theirMetres, s), ourPoints, ourMetres);
    samples.push({ theirMetres: s, ourMetres: near.metres, distance: near.distance });
  }
  const worst = samples.reduce((a, b) => (b.distance > a.distance ? b : a));
  const mean = samples.reduce((sum, x) => sum + x.distance, 0) / samples.length;
  return { count: samples.length, mean, worst };
}

function interpolate(points, metres, s) {
  let i = 1;
  while (i < metres.length - 1 && metres[i] < s) i++;
  const span = metres[i] - metres[i - 1];
  const at = span === 0 ? 0 : (s - metres[i - 1]) / span;
  return {
    x: points[i - 1].x + (points[i].x - points[i - 1].x) * at,
    y: points[i - 1].y + (points[i].y - points[i - 1].y) * at,
  };
}

function nearestOn(point, points, metres) {
  let best = { distance: Infinity, metres: 0 };
  for (let i = 1; i < points.length; i++) {
    const near = toSegment(point, points[i - 1], points[i]);
    if (near.distance < best.distance) {
      best = { distance: near.distance, metres: metres[i - 1] + (metres[i] - metres[i - 1]) * near.at };
    }
  }
  return best;
}

function toSegment(p, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const span = dx * dx + dy * dy;
  const at = span === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / span));
  return { distance: Math.hypot(p.x - (a.x + dx * at), p.y - (a.y + dy * at)), at };
}

// The atlas line in this repository's own profile, at its own length: a reader
// that later hands it to the module generator is told it does not end at the
// published lap length, because it was written not to pretend otherwise.
async function writeAtlasGeometry(circuit, slug, url, outline, corners, theirMetres) {
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
  ];
  const body = features.map((f) => `    ${JSON.stringify(f)}`).join(",\n");
  const path = join(repoDir, "app", "scripts", "geometry", `${slug}.atlas.geojson`);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `{"type": "FeatureCollection", "features": [\n${body}\n]}\n`);
}

function print(slug, circuit, every, length, originDistance, apart, atCorners) {
  const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;
  const distances = atCorners.map((c) => c.distance);
  const laps = atCorners.map((c) => c.ourMetres - c.theirMetres);
  const worstLap = laps.reduce((a, b) => (Math.abs(b) > Math.abs(a) ? b : a), 0);
  console.log(`== ${slug}: the atlas line against the geometry this app draws`);
  console.log(
    `length: measured ${length.toFixed(1)} m against the published ${circuit.lapLength} m ` +
      `(${signed(length - circuit.lapLength)}); the lap starts ${originDistance.toFixed(1)} m from the published timing line`,
  );
  console.log(
    `lines sampled every ${every} m (${apart.count}): mean apart ${apart.mean.toFixed(1)} m, ` +
      `max ${apart.worst.distance.toFixed(1)} m at their ${apart.worst.theirMetres.toFixed(0)} m, our ${apart.worst.ourMetres.toFixed(1)} m`,
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
}

function round1(n) {
  return Math.round(n * 10) / 10;
}

function signed(n) {
  return `${n >= 0 ? "+" : ""}${n.toFixed(1)}`;
}
