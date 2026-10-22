// The pipeline every circuit's geometry file is written by: take a relation's
// surveyed points, chain its ways into a lap, stretch the lap to the length the
// circuit publishes, simplify it, and write the geometry GeoJSON.
//
// A circuit's config — its relation, its published lap length, the word its
// rounds are known by — is what this module is given; `write-geometry.mjs` is
// what runs it. Where the written file stands, who reads it and what holds it
// is `circuits/README.md`.
//
//     node circuits/write-geometry.mjs <circuit> [overpass.json]
//     node circuits/write-geometry.mjs <circuit> --from-geojson [geometry.json]
//
// Given an Overpass answer as a file, reads it rather than asking.
// `--from-geojson` writes nothing: it runs the checks the app's runtime decoder
// will run, over the kept geometry and with no OpenStreetMap. The answer a
// geometry was drawn from is kept beside each circuit's config as the
// pipeline's frozen input, which `regenerate-geometry.mjs` re-runs this module
// over; a live regeneration asks OpenStreetMap again regardless.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and every
// geometry and module written here is a derivative of it.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// Every tool in this directory works from the repository root, which is where
// the configs' `geojson` paths and the data and export directories live.
export const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const overpassRunners = [
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
];
const userAgent = "elm-motorsport-analysis/1.0 (circuit geometry)";

// Metres a simplified line may stray from the surveyed one.
const tolerance = 1.0;

// The earth every drawing is measured on: the same sphere
// `Motorsport.Circuit.Geodesy` projects through.
const radius = 6371008.8;

/**
 * A circuit: where its geometry is surveyed from, what the lap is stretched to,
 * and the published sector lines the geometry carries beside the lap.
 *
 * `finishRole` names the relation member the lap is measured from. `timingLine`
 * is where it stands on the earth as the circuit itself publishes it, in which
 * case a run checks the role answered to; a relation may tag several lines and
 * pick the wrong one out of them without failing a build.
 *
 * @typedef {object} Circuit
 * @property {number} relation
 * @property {string} slug      the circuit word `Motorsport.Circuit.jsonValue` sends
 * @property {string} finishRole
 * @property {{ lat: number, lon: number, within?: number }} [timingLine]
 * @property {number} lapLength
 * @property {number[]} [sectorMapStretches] the circuit's published sector lengths
 * @property {string} [sectorsSource]         who publishes them
 * @property {string} geojson   the geometry file, from the repository root
 * @property {string} script    this file, named in the reports
 * @property {string} survey    e.g. `The Circuit of the Americas`
 */

/** Whether the module named is the script the process was started from, as
 * against a config another script imported to read a published length out of.
 * `import.meta.url` is the caller's own and not this file's, so it is passed
 * in. */
export function isEntry(moduleUrl) {
  return pathToFileURL(process.argv[1] ?? "").href === moduleUrl;
}

/** Write the circuit's geometry, or check the kept one. `argv` is the script's
 * own:
 *
 *   - `--from-geojson [file]` reads a geometry file -- the circuit's kept one
 *     when no file is named -- runs every check on it, and writes nothing.
 *   - a file names an Overpass answer to read instead of asking.
 *   - neither asks OpenStreetMap, and a run that asks writes the served file
 *     from a survey taken *now*.
 */
export async function main(circuit, argv) {
  try {
    const from = valueOf(argv, "--from-geojson");
    if (from !== null) {
      const path = from || join(repoDir, circuit.geojson);
      report("checked", circuit, geometryFromGeoJson(JSON.parse(await readFile(path, "utf8")), circuit));
      return;
    }
    const [file] = argv.filter((a) => !a.startsWith("--"));
    const geometry = lapOf(await answer(circuit.relation, file), circuit);
    await writeGeoJson(circuit, geometry);
    report("written", circuit, geometry);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

function report(done, circuit, geometry) {
  const surveyed = geometry.surveyedLength === null ? "" : `, surveyed ${geometry.surveyedLength.toFixed(1)} m`;
  const of = geometry.counts === null ? "" : ` of ${geometry.counts.lap}`;
  const pit = geometry.counts === null ? "" : ` of ${geometry.counts.of}`;
  console.log(
    `${circuit.slug} ${done}: centreline ${geometry.centreline.length} points${of}${surveyed}; ` +
      `direction ${geometry.direction}; ` +
      `pit lane ${geometry.pitLane.length} points${pit}; ` +
      `frame origin ${geometry.frame.origin.lat}, ${geometry.frame.origin.lon} parallel ${geometry.frame.parallel}`,
  );
}

/** The value following `flag`, the empty string when it stands alone, and null
 * when the flag is absent. */
export function valueOf(argv, flag) {
  const at = argv.indexOf(flag);
  return at === -1 ? null : argv[at + 1] || "";
}

/** The answer from a file if one was given, and from OpenStreetMap if not. */
export async function answer(relation, file) {
  return file ? JSON.parse(await readFile(file, "utf8")) : ask(relation);
}

/** One query, walked over the runners twice each: a busy one answers 502 or
 * 504 — or 200 with an HTML error page behind a proxy, so the body is looked at
 * and not just the status — and the next answers the same query. */
export async function askOverpass(query) {
  let failure = "no runner was reached";
  const tries = overpassRunners.length * 2;
  for (const [runner, url] of overpassRunners.entries()) {
    for (let attempt = 1; attempt <= 2; attempt++) {
      const left = tries - (runner * 2 + attempt);
      try {
        const response = await fetch(url, {
          method: "POST",
          headers: { "User-Agent": userAgent, "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ data: query }),
        });
        const body = await response.text();
        if (!response.ok) throw new Error(`Overpass answered ${response.status}`);
        if (!"{[".includes(body[0])) throw new Error("Overpass answered with something that is not JSON");
        return JSON.parse(body);
      } catch (error) {
        failure = error.message;
        if (left > 0) await sleep(attempt * 4000);
      }
    }
  }
  throw new Error(`every Overpass runner failed: ${failure}`);
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** The Overpass answer for one relation: its ways with their tags, and nodes. */
export async function ask(relation) {
  return askOverpass(`[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;`);
}

/**
 * The lap, the pit lane and the frame, in the drawing's own metres.
 *
 * Every point keeps the degrees it was surveyed at; the metres are this
 * module's working, and Elm re-derives them from the frame.
 */
export function lapOf(osm, circuit) {
  const rel = osm.elements.find((e) => e.type === "relation" && e.id === circuit.relation);
  const ways = new Map(osm.elements.filter((e) => e.type === "way").map((w) => [w.id, w]));
  const nodes = new Map(osm.elements.filter((e) => e.type === "node").map((n) => [n.id, n]));
  const start = rel.members.find((m) => m.role === circuit.finishRole).ref;

  nearTimingLine(rel, nodes, start, circuit);

  const track = chain(rel.members.filter((m) => m.type === "way" && m.role === "").map((m) => ways.get(m.ref)), start, nodes);
  const lap = [...rotate(track.slice(0, -1), start), start];
  const pit = chain(rel.members.filter((m) => m.role === "pit_lane").map((m) => ways.get(m.ref)), null, nodes);

  const lapNodes = lap.map((id) => nodes.get(id));
  const pitNodes = pit.map((id) => nodes.get(id));
  const { project, parallel } = projection([...lapNodes, ...pitNodes]);
  const lapPoints = lapNodes.map(project);
  const pitPoints = pitNodes.map(project);

  const surveyed = cumulative(lapPoints);
  const stretch = circuit.lapLength / surveyed[surveyed.length - 1];
  const metres = surveyed.map((m) => m * stretch);
  const direction = turnDirection(lapPoints);

  const half = Math.floor(lapPoints.length / 2);
  const kept = [
    ...simplify(lapPoints, 0, half).slice(0, -1),
    ...simplify(lapPoints, half, lapPoints.length - 1),
  ];
  const keptPit = simplify(pitPoints, 0, pitPoints.length - 1);

  const frame = frameOf([...lapNodes, ...pitNodes], parallel);
  const fromNode = (node) => ({ lat: node.lat, lon: node.lon });

  return {
    centreline: kept.map((i) => ({ ...fromNode(lapNodes[i]), metres: roundTenth(metres[i]) })),
    pitLane: keptPit.map((i) => fromNode(pitNodes[i])),
    frame,
    direction,
    surveyedAt: osm.osm3s?.timestamp_osm_base,
    counts: { kept: kept.length, lap: lapPoints.length, pit: keptPit.length, of: pitPoints.length },
    surveyedLength: surveyed[surveyed.length - 1],
  };
}

// -- the geometry GeoJSON -----------------------------------------------------
//
// The profile both sides read: EPSG:4326 throughout, as the Atlas keeps it; one
// `outline` LineString whose `metres` property holds, point for point, how far
// round the lap each stands, in the circuit's published metres; one `pit_lane`
// LineString with no metres because nothing times along it; the `direction` the
// chained survey runs, which is which way a car goes round the drawing; and the
// frame the degrees project through, whole, so the module's `Geodesy.frame` is
// a copy and not a re-derivation. A `basis` says what kind of line it is -- the
// OSM centreline stretched, a measurement's midline -- so a file cannot be
// mistaken for the other, and the ODbL copyright travels in `source` and
// `license`. Where the circuit itself publishes the lines it times to, those
// authored stretches travel as `sectors`, so a check of the timing lines reads
// data rather than a script's config.

export function geoJsonString(circuit, geometry) {
  const outline = feature(
    {
      role: "outline",
      circuit: circuit.slug,
      basis: "osm-centreline",
      source: `https://www.openstreetmap.org/relation/${circuit.relation}`,
      license: "ODbL",
      surveyed_at: geometry.surveyedAt,
      direction: geometry.direction,
      lap_length_m: circuit.lapLength,
      surveyed_length_m: geometry.surveyedLength,
      sectors:
        circuit.sectorMapStretches === undefined
          ? undefined
          : { source: circuit.sectorsSource, stretches: circuit.sectorMapStretches },
      frame: geometry.frame,
      metres: geometry.centreline.map((p) => p.metres),
    },
    geometry.centreline.map((p) => [p.lon, p.lat]),
  );
  const pitLane = feature(
    { role: "pit_lane", circuit: circuit.slug, basis: "osm-centreline", license: "ODbL" },
    geometry.pitLane.map((p) => [p.lon, p.lat]),
  );
  return `{"type": "FeatureCollection", "features": [\n${[outline, pitLane].join(",\n")}\n]}\n`;
}

// Coordinates, metres and every other array print on one line each, so a kept
// geometry is one line per property rather than one per number -- a refreshed
// survey reads as two changed lines per feature.
function feature(props, coordinates) {
  const entries = Object.entries(props)
    .filter(([, value]) => value !== undefined)
    .map(([key, value]) => `        ${JSON.stringify(key)}: ${JSON.stringify(value)}`);
  return (
    `    {\n      "type": "Feature",\n      "properties": {\n${entries.join(",\n")}\n      },\n` +
    `      "geometry": ${JSON.stringify({ type: "LineString", coordinates })}\n    }`
  );
}

export async function writeGeoJson(circuit, geometry) {
  const path = join(repoDir, circuit.geojson);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, geoJsonString(circuit, geometry));
}

/** The geometry a circuit is drawn from, read back out of a geometry file. The
 * outline's metres are checked against the file's own claims: one per point,
 * going up, ending where the published lap length says -- because a file that
 * drifted from its generator would otherwise reach the drawing with the
 * survey's authority and none of its own. The `direction` is read as the Elm
 * decoder reads it: a required word, so a file that cannot say which way a car
 * goes round it fails here and fails there alike. */
export function geometryFromGeoJson(json, circuit) {
  const features = json.features ?? [];
  const outline = features.find((f) => f.properties?.role === "outline");
  const pit = features.find((f) => f.properties?.role === "pit_lane");
  if (!outline || !pit) throw new Error("the geometry holds no outline or no pit lane");
  const props = outline.properties;
  const coords = outline.geometry.coordinates;
  const metres = props.metres;
  if (!["clockwise", "counter_clockwise"].includes(props.direction)) {
    throw new Error(`the outline says it runs ${JSON.stringify(props.direction)}, which is not a direction`);
  }
  if (metres.length !== coords.length) throw new Error(`${metres.length} metres for ${coords.length} points`);
  for (let i = 1; i < metres.length; i++) {
    if (metres[i] < metres[i - 1]) throw new Error(`metres go backwards at point ${i}`);
  }
  if (Math.abs(metres[metres.length - 1] - circuit.lapLength) > 0.1) {
    throw new Error(
      `the outline ends at ${metres[metres.length - 1]} m, not the published ${circuit.lapLength} m`,
    );
  }
  const sectors = props.sectors ?? null;
  if (sectors) sectorLines(sectors, circuit.lapLength);
  return {
    centreline: coords.map((c, i) => ({ ...onEarth(c), metres: metres[i] })),
    pitLane: pit.geometry.coordinates.map(onEarth),
    frame: props.frame,
    direction: props.direction,
    surveyedAt: props.surveyed_at ?? null,
    surveyedLength: props.surveyed_length_m ?? null,
    sectors,
    counts: null,
  };
}

/** The intermediate timing lines a circuit's published stretches imply: each
 * stretch ends where the next begins, and the last ends at the line the lap is
 * measured from — which is where it started, so it is not a line to place. A
 * line is named for the sector that begins at it, so every tool reading the
 * same map's stretches — the atlas reading, the timing-lines check — calls the
 * same line the same thing. The only thing stretches are trusted with is the
 * lap length they add up to; where the times place them is
 * `check-timing-lines.mjs`'s to answer. */
export function sectorLines(sectors, lapLength) {
  const total = sectors.stretches.reduce((sum, stretch) => sum + stretch, 0);
  if (Math.abs(total - lapLength) > 0.15) {
    throw new Error(`the sectors add up to ${total} m, not the published ${lapLength} m`);
  }
  const lines = [];
  let at = 0;
  for (const stretch of sectors.stretches.slice(0, -1)) {
    at += stretch;
    lines.push({ id: `s${lines.length + 2}`, metres: at });
  }
  return lines;
}

/**
 * The line the lap is measured from, checked against where the circuit says it
 * stands.
 *
 * A relation may tag more than one line -- a start line and a finish line, which
 * are not the same place -- and every `metres` below is measured from whichever
 * role was answered to. Getting it wrong moves the whole field down the lap by
 * the distance between the two and draws fine doing it.
 */
function nearTimingLine(rel, nodes, chosen, circuit) {
  if (!circuit.timingLine) return;
  const within = circuit.timingLine.within ?? 10;
  const distance = (node) => apart(circuit.timingLine, node);

  if (distance(nodes.get(chosen)) <= within) return;

  const lines = rel.members
    .filter((m) => m.type === "node")
    .map((m) => `role=${m.role} is ${distance(nodes.get(m.ref)).toFixed(1)} m from it`)
    .join("; ");
  throw new Error(
    `role=${circuit.finishRole} is ${distance(nodes.get(chosen)).toFixed(1)} m from the published timing line, ` +
      `which is not within ${within} m. The relation's lines: ${lines}.`,
  );
}

export const degreesToMetres = (Math.PI / 180) * radius;

/** Metres between two places, east-west taken at the parallel of the second —
 * an approximation only ever asked of distances across a circuit's few
 * kilometres. */
export function apart(a, b) {
  const east = Math.cos((b.lat * Math.PI) / 180);
  return Math.hypot(b.lat - a.lat, (b.lon - a.lon) * east) * degreesToMetres;
}

/** Metres along a list of places, each stretch taken at its own parallel. */
export function polylineMetres(points) {
  let metres = 0;
  for (let i = 1; i < points.length; i++) metres += apart(points[i - 1], points[i]);
  return metres;
}

// The relation lists its ways in no particular order, and a way open to traffic
// both ways may be drawn against the direction of the race. A oneway way is
// drawn the way it is driven, so the chain follows those and turns the others.
function chain(members, start, nodes) {
  const segments = members.map((w) => ({
    id: w.id,
    nodes: w.nodes,
    oneway: w.tags?.oneway === "yes",
  }));
  const first =
    start === null
      ? segments.find((s) => !segments.some((o) => o !== s && o.nodes.at(-1) === s.nodes[0]))
      : segments.find((s) => s.nodes.includes(start) && s.oneway);
  const used = new Set([first.id]);
  const ids = [...first.nodes];
  for (;;) {
    const end = ids.at(-1);
    const next =
      segments.find((s) => !used.has(s.id) && s.nodes[0] === end) ??
      segments.find((s) => !used.has(s.id) && !s.oneway && s.nodes.at(-1) === end);
    if (!next) break;
    used.add(next.id);
    ids.push(...(next.nodes[0] === end ? next.nodes : [...next.nodes].reverse()).slice(1));
  }
  const left = segments.filter((s) => !used.has(s.id));
  if (left.length > 0) {
    const stopped = nodes.get(ids.at(-1));
    throw new Error(`ways left out of the chain: ${left.map((s) => straggled(s, stopped, nodes)).join("; ")}`);
  }
  if (start !== null && ids.at(-1) !== ids[0]) {
    throw new Error(
      `the lap does not close: its last point stands ${apart(nodes.get(ids.at(-1)), nodes.get(ids[0])).toFixed(1)} m from its first`,
    );
  }
  return ids;
}

/** One way the chain could not take, reported with what decides its remedy:
 * its length, how far its nearest end stands from where the chain stopped, and
 * whether it is driven one way. A oneway way lying at the stop is an
 * orientation the survey disagrees with; a way tens of metres off is ground
 * OpenStreetMap does not connect; a short one far from everything is usually a
 * road with no business in the relation. */
function straggled(segment, stopped, nodes) {
  const points = segment.nodes.map((id) => nodes.get(id));
  const gap = Math.min(apart(stopped, points[0]), apart(stopped, points.at(-1)));
  const near = gap < 0.5;
  const drive = segment.oneway ? (near ? ", driven the other way" : ", oneway") : "";
  return (
    `${segment.id} is ${Math.round(polylineMetres(points))} m, ` +
    `nearest end ${near ? "at" : `${gap.toFixed(1)} m from`} where the chain stopped${drive}`
  );
}

function rotate(ids, start) {
  const i = ids.indexOf(start);
  return [...ids.slice(i), ...ids.slice(0, i)];
}

// Equirectangular about the circuit's own latitude: across the few km a circuit
// covers its error is far below the tolerance the line is simplified to. `y`
// runs south, as SVG's does, so north is up.
export function projection(points) {
  const parallel = points.reduce((sum, p) => sum + p.lat, 0) / points.length;
  const east = Math.cos(parallel * (Math.PI / 180));
  const project = ({ lat, lon }) => ({
    x: lon * (Math.PI / 180) * radius * east,
    y: -lat * (Math.PI / 180) * radius,
  });
  return { project, parallel };
}

// The drawing's metres are measured from the frame's origin: the north-west
// corner of the survey, the place this module's line was drawn from.
function frameOf(points, parallel) {
  return {
    origin: {
      lat: Math.max(...points.map((p) => p.lat)),
      lon: Math.min(...points.map((p) => p.lon)),
    },
    parallel,
  };
}

export function cumulative(points) {
  const out = [0];
  for (let i = 1; i < points.length; i++) {
    out.push(out[i - 1] + Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y));
  }
  return out;
}

// Which way the closed loop runs, from the shoelace sum in the drawing's own
// metres: positive is clockwise, because this projection's y runs south. A
// circuit relation whose ways are mis-oriented says so too.
function turnDirection(points) {
  let sum = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum > 0 ? "clockwise" : "counter_clockwise";
}

// Ramer-Douglas-Peucker over indices, so a kept point keeps the distance it was
// surveyed at rather than the shorter one the simplified line would give it.
function simplify(points, from, to) {
  const a = points[from];
  const b = points[to];
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const norm = Math.hypot(dx, dy);
  let furthest = 0;
  let at = -1;
  for (let i = from + 1; i < to; i++) {
    const p = points[i];
    const d =
      norm === 0 ? Math.hypot(p.x - a.x, p.y - a.y) : Math.abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x) / norm;
    if (d > furthest) {
      furthest = d;
      at = i;
    }
  }
  if (furthest <= tolerance) return [from, to];
  return [...simplify(points, from, at).slice(0, -1), ...simplify(points, at, to)];
}

/** A pair of degrees as the place on earth it names. */
export const onEarth = ([lon, lat]) => ({ lat, lon });

/** A distance in metres, kept to the tenth of a metre the survey is held at —
 * and every baseline rendered from it. */
export function roundTenth(n) {
  return Math.round(n * 10) / 10;
}

