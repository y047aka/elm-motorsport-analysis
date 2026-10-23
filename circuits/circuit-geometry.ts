// The pipeline every circuit's geometry file is written by: take a relation's
// surveyed points, chain its ways into a lap, stretch the lap to the length the
// circuit publishes, simplify it, and write the geometry GeoJSON.
//
// A circuit's config — its relation, its published lap length, the word its
// rounds are known by — is what this module is given; `write-geometry.ts` is
// what runs it. Where the written file stands, who reads it and what holds it
// is `circuits/README.md`.
//
//     node circuits/write-geometry.ts <circuit> [overpass.json]
//     node circuits/write-geometry.ts <circuit> --from-geojson [geometry.json]
//
// Given an Overpass answer as a file, reads it rather than asking.
// `--from-geojson` writes nothing: it runs the checks the app's runtime decoder
// will run, over the kept geometry and with no OpenStreetMap. The answer a
// geometry was drawn from is kept beside each circuit's config as the
// pipeline's frozen input, which `regenerate-geometry.ts` re-runs this module
// over; a live regeneration asks OpenStreetMap again regardless.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and every
// geometry and module written here is a derivative of it.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { outlineOf, pitLaneOf } from "./geometry-file.ts";

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
// `Motorsport.Circuit.Geodesy` projects through. Exported because tests
// measure against it rather than restating it.
export const earthRadius = 6371008.8;

/** A place on earth, in the degrees OpenStreetMap gives it. */
export type Place = { lat: number; lon: number };

/** A place in the drawing's metres; `y` runs south, as SVG's does. */
export type Point = { x: number; y: number };

/** A place on the lap with how far round the lap it stands, in the circuit's
 * published metres. */
export type MetredPlace = Place & { metres: number };

export type Direction = "clockwise" | "counter_clockwise";

/** The frame the degrees project through: its origin the north-west corner of
 * the survey, `parallel` the latitude the east-west is scaled at. */
export type Frame = { origin: Place; parallel: number };

/** A circuit's published sector lengths, whose only trusted claim is the lap
 * length they add up to. */
export type Sectors = { source?: string; stretches: number[] };

/** An intermediate timing line, named for the sector that begins at it. */
export type SectorLine = { id: string; metres: number };

/** The properties an outline feature is written with — a survey's stretched
 * to a published lap, or a measurement at its own length. What a reader of a
 * kept file may ask for; the claims that matter to a drawing are checked on
 * reading, not here. */
export type OutlineProperties = {
  role?: string;
  circuit?: string;
  basis?: string;
  source?: string;
  license?: string;
  surveyed_at?: string;
  direction?: string;
  lap_length_m?: number;
  surveyed_length_m?: number;
  sectors?: Sectors;
  frame?: Frame;
  metres?: number[];
  [extra: string]: unknown;
};

/** One feature of a geometry file of this repository's profile; coordinates
 * are degrees, lon before lat, as GeoJSON gives them. */
export type GeometryFeature = {
  properties?: OutlineProperties;
  geometry?: { type?: string; coordinates?: [number, number][] };
};

export type GeometryFile = { type?: string; features?: GeometryFeature[] };

export type Counts = { kept: number; lap: number; pit: number; of: number };

export type OsmTags = Record<string, string>;

export type OsmNode = { type: "node"; id: number; lat: number; lon: number; tags?: OsmTags };

/** A way with its node references, as `out body` serves it; an `out geom`
 * answer — what `geometry-probe` asks — carries the same line projected into
 * a `geometry` instead. */
export type OsmWay = { type: "way"; id: number; nodes?: number[]; tags?: OsmTags; geometry?: Place[] };

/** One member of a relation; the role is "" for the ways a lap chains from. */
export type OsmMember = { type: string; role: string; ref: number };

export type OsmRelation = { type: "relation"; id: number; members?: OsmMember[]; tags?: OsmTags };

export type OsmElement = OsmNode | OsmWay | OsmRelation;

/** An Overpass answer as the runner served it. */
export type OverpassAnswer = {
  elements: OsmElement[];
  osm3s?: { timestamp_osm_base?: string };
};

/**
 * A circuit: where its geometry is surveyed from, what the lap is stretched to,
 * and the published sector lines the geometry carries beside the lap.
 *
 * `finishRole` names the relation member the lap is measured from. `timingLine`
 * is where it stands on the earth as the circuit itself publishes it, in which
 * case a run checks the role answered to; a relation may tag several lines and
 * pick the wrong one out of them without failing a build.
 */
export interface Circuit {
  relation: number;
  /** The circuit word `Motorsport.Circuit.jsonValue` sends. */
  slug: string;
  finishRole: string;
  timingLine?: Place & { within?: number };
  lapLength: number;
  /** The circuit's published sector lengths. */
  sectorMapStretches?: number[];
  /** Who publishes them. */
  sectorsSource?: string;
  /** The track-atlas layer a measured midline is read off. */
  atlas?: { url: string };
  /** The geometry file, from the repository root. */
  geojson: string;
  /** This file, named in the reports. */
  script: string;
  /** e.g. `The Circuit of the Americas`. */
  survey: string;
}

/** What the pipeline wrote, or read back out of a kept file: the lap and the
 * pit lane as places on earth, the lap with its published metres, and the
 * frame Elm projects through. `counts` is the pipeline's own and null of a
 * read-back file, which cannot say what a simplification left out. */
export interface Geometry {
  centreline: MetredPlace[];
  pitLane: Place[];
  frame: Frame;
  direction: Direction;
  surveyedAt?: string | null;
  surveyedLength: number | null;
  counts: Counts | null;
  sectors?: Sectors | null;
}

/** What a failure says, whether it is an Error or what a runner threw. */
export function reason(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Whether the module named is the script the process was started from.
 * `geometry-diff.ts` asks because it is a command to the shell and a library
 * to the atlas reading. `import.meta.url` is the caller's own and not this
 * file's, so it is passed in. */
export function isEntry(moduleUrl: string): boolean {
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
export async function main(circuit: Circuit, argv: string[]): Promise<void> {
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
    console.error(reason(error));
    process.exitCode = 1;
  }
}

function report(done: string, circuit: Circuit, geometry: Geometry): void {
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
export function valueOf(argv: string[], flag: string): string | null {
  const at = argv.indexOf(flag);
  return at === -1 ? null : argv[at + 1] || "";
}

/** The answer from a file if one was given, and from OpenStreetMap if not. */
async function answer(relation: number, file: string | undefined): Promise<OverpassAnswer> {
  return file ? JSON.parse(await readFile(file, "utf8")) : ask(relation);
}

/** One query, walked over the runners twice each: a busy one answers 502 or
 * 504 — or 200 with an HTML error page behind a proxy, so the body is looked at
 * and not just the status — and the next answers the same query. */
export async function askOverpass(query: string): Promise<OverpassAnswer> {
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
        failure = reason(error);
        if (left > 0) await sleep(attempt * 4000);
      }
    }
  }
  throw new Error(`every Overpass runner failed: ${failure}`);
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** The Overpass answer for one relation: its ways with their tags, and nodes. */
export async function ask(relation: number): Promise<OverpassAnswer> {
  return askOverpass(`[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;`);
}

/**
 * The lap, the pit lane and the frame, in the drawing's own metres.
 *
 * Every point keeps the degrees it was surveyed at; the metres are this
 * module's working, and Elm re-derives them from the frame.
 */
export function lapOf(osm: OverpassAnswer, circuit: Circuit): Geometry {
  const rel = osm.elements.find((el): el is OsmRelation => el.type === "relation" && el.id === circuit.relation);
  if (!rel) throw new Error(`the answer holds no relation ${circuit.relation}`);
  const members = rel.members ?? [];
  const ways = new Map<number, OsmWay>(
    osm.elements.filter((el): el is OsmWay => el.type === "way").map((w) => [w.id, w]),
  );
  const nodes = new Map<number, OsmNode>(
    osm.elements.filter((el): el is OsmNode => el.type === "node").map((n) => [n.id, n]),
  );
  const wayOf = (ref: number): OsmWay => {
    const way = ways.get(ref);
    if (!way) throw new Error(`relation ${circuit.relation} names way ${ref}, which the answer does not hold`);
    return way;
  };
  const start = members.find((m) => m.role === circuit.finishRole)?.ref;
  if (start === undefined) {
    throw new Error(`relation ${circuit.relation} tags no member with role '${circuit.finishRole}'`);
  }

  nearTimingLine(members, nodes, start, circuit);

  const track = chain(members.filter((m) => m.type === "way" && m.role === "").map((m) => wayOf(m.ref)), start, nodes);
  const lap = [...rotate(track.slice(0, -1), start), start];
  const pit = chain(members.filter((m) => m.role === "pit_lane").map((m) => wayOf(m.ref)), null, nodes);

  const lapNodes = lap.map((id) => nodes.get(id)!);
  const pitNodes = pit.map((id) => nodes.get(id)!);
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
  const fromNode = (node: Place): Place => ({ lat: node.lat, lon: node.lon });

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

export function geoJsonString(circuit: Circuit, geometry: Geometry): string {
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
    geometry.centreline.map((p): [number, number] => [p.lon, p.lat]),
  );
  const pitLane = feature(
    { role: "pit_lane", circuit: circuit.slug, basis: "osm-centreline", license: "ODbL" },
    geometry.pitLane.map((p): [number, number] => [p.lon, p.lat]),
  );
  return `{"type": "FeatureCollection", "features": [\n${[outline, pitLane].join(",\n")}\n]}\n`;
}

// Coordinates, metres and every other array print on one line each, so a kept
// geometry is one line per property rather than one per number -- a refreshed
// survey reads as two changed lines per feature.
function feature(props: Record<string, unknown>, coordinates: [number, number][]): string {
  const entries = Object.entries(props)
    .filter(([, value]) => value !== undefined)
    .map(([key, value]) => `        ${JSON.stringify(key)}: ${JSON.stringify(value)}`);
  return (
    `    {\n      "type": "Feature",\n      "properties": {\n${entries.join(",\n")}\n      },\n` +
    `      "geometry": ${JSON.stringify({ type: "LineString", coordinates })}\n    }`
  );
}

async function writeGeoJson(circuit: Circuit, geometry: Geometry): Promise<void> {
  const path = join(repoDir, circuit.geojson);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, geoJsonString(circuit, geometry));
}

/** The geometry a circuit is drawn from, read back out of a geometry file --
 * the profile read the way every reader of a kept file reads it, and then the
 * circuit's own claims checked on top: the last metre ending where *this*
 * circuit's published lap length says, the published stretches adding up to
 * it, a direction the file can say -- because a file that drifted from its
 * generator would otherwise reach the drawing with the survey's authority and
 * none of its own. The `direction` is read as the Elm decoder reads it: a
 * required word, so a file that cannot say which way a car goes round it fails
 * here and fails there alike. */
export function geometryFromGeoJson(json: GeometryFile, circuit: Circuit): Geometry {
  const outline = outlineOf(json, circuit.slug);
  const pit = pitLaneOf(json, circuit.slug);
  const props = outline.props;
  const metres = outline.metres;
  const direction = props.direction;
  if (direction !== "clockwise" && direction !== "counter_clockwise") {
    throw new Error(`the outline says it runs ${JSON.stringify(direction)}, which is not a direction`);
  }
  if (Math.abs(metres[metres.length - 1] - circuit.lapLength) > 0.1) {
    throw new Error(
      `the outline ends at ${metres[metres.length - 1]} m, not the published ${circuit.lapLength} m`,
    );
  }
  const sectors = props.sectors ?? null;
  if (sectors) sectorLines(sectors, circuit.lapLength);
  const frame = props.frame;
  if (!frame) throw new Error("the outline carries no frame to project through");
  return {
    centreline: outline.coords.map((c, i) => ({ ...onEarth(c), metres: metres[i] })),
    pitLane: pit.map(onEarth),
    frame,
    direction,
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
 * `check-timing-lines.ts`'s to answer. */
export function sectorLines(sectors: Sectors, lapLength: number): SectorLine[] {
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
function nearTimingLine(members: OsmMember[], nodes: Map<number, Place>, chosen: number, circuit: Circuit): void {
  const timingLine = circuit.timingLine;
  if (!timingLine) return;
  const within = timingLine.within ?? 10;
  const distance = (node: Place) => apart(timingLine, node);

  if (distance(nodes.get(chosen)!) <= within) return;

  const lines = members
    .filter((m) => m.type === "node")
    .map((m) => `role=${m.role} is ${distance(nodes.get(m.ref)!).toFixed(1)} m from it`)
    .join("; ");
  throw new Error(
    `role=${circuit.finishRole} is ${distance(nodes.get(chosen)!).toFixed(1)} m from the published timing line, ` +
      `which is not within ${within} m. The relation's lines: ${lines}.`,
  );
}

const degreesToMetres = (Math.PI / 180) * earthRadius;

/** Metres between two places, east-west taken at the parallel of the second —
 * an approximation only ever asked of distances across a circuit's few
 * kilometres. */
export function apart(a: Place, b: Place): number {
  const east = Math.cos((b.lat * Math.PI) / 180);
  return Math.hypot(b.lat - a.lat, (b.lon - a.lon) * east) * degreesToMetres;
}

/** Metres along a list of places, each stretch taken at its own parallel. */
export function polylineMetres(points: Place[]): number {
  let metres = 0;
  for (let i = 1; i < points.length; i++) metres += apart(points[i - 1], points[i]);
  return metres;
}

// The relation lists its ways in no particular order, and a way open to traffic
// both ways may be drawn against the direction of the race. A oneway way is
// drawn the way it is driven, so the chain follows those and turns the others.
type Segment = { id: number; nodes: number[]; oneway: boolean };

function chain(members: OsmWay[], start: number | null, nodes: Map<number, Place>): number[] {
  const segments: Segment[] = members.map((w) => ({
    id: w.id,
    nodes: w.nodes ?? [],
    oneway: w.tags?.oneway === "yes",
  }));
  const first =
    start === null
      ? segments.find((s) => !segments.some((o) => o !== s && o.nodes.at(-1) === s.nodes[0]))
      : segments.find((s) => s.nodes.includes(start) && s.oneway);
  if (!first) throw new Error("the relation holds no way the lap can start from");
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
    const end = nodes.get(ids.at(-1)!);
    if (!end) throw new Error("the chain ended at a node the answer does not hold");
    throw new Error(`ways left out of the chain: ${left.map((s) => straggled(s, end, nodes)).join("; ")}`);
  }
  if (start !== null && ids.at(-1) !== ids[0]) {
    throw new Error(
      `the lap does not close: its last point stands ${apart(nodes.get(ids.at(-1)!)!, nodes.get(ids[0]!)!).toFixed(1)} m from its first`,
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
function straggled(segment: Segment, stopped: Place, nodes: Map<number, Place>): string {
  const points = segment.nodes.map((id) => nodes.get(id)!);
  const gap = Math.min(apart(stopped, points[0]), apart(stopped, points.at(-1)!));
  const near = gap < 0.5;
  const drive = segment.oneway ? (near ? ", driven the other way" : ", oneway") : "";
  return (
    `${segment.id} is ${Math.round(polylineMetres(points))} m, ` +
    `nearest end ${near ? "at" : `${gap.toFixed(1)} m from`} where the chain stopped${drive}`
  );
}

function rotate(ids: number[], start: number): number[] {
  const i = ids.indexOf(start);
  return [...ids.slice(i), ...ids.slice(0, i)];
}

// Equirectangular about the circuit's own latitude: across the few km a circuit
// covers its error is far below the tolerance the line is simplified to. `y`
// runs south, as SVG's does, so north is up.
export function projection(points: Place[]): { project: (p: Place) => Point; parallel: number } {
  const parallel = points.reduce((sum, p) => sum + p.lat, 0) / points.length;
  const east = Math.cos(parallel * (Math.PI / 180));
  const project = ({ lat, lon }: Place): Point => ({
    x: lon * (Math.PI / 180) * earthRadius * east,
    y: -lat * (Math.PI / 180) * earthRadius,
  });
  return { project, parallel };
}

// The drawing's metres are measured from the frame's origin: the north-west
// corner of the survey, the place this module's line was drawn from.
function frameOf(points: Place[], parallel: number): Frame {
  return {
    origin: {
      lat: Math.max(...points.map((p) => p.lat)),
      lon: Math.min(...points.map((p) => p.lon)),
    },
    parallel,
  };
}

export function cumulative(points: Point[]): number[] {
  const out = [0];
  for (let i = 1; i < points.length; i++) {
    out.push(out[i - 1] + Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y));
  }
  return out;
}

// Which way the closed loop runs, from the shoelace sum in the drawing's own
// metres: positive is clockwise, because this projection's y runs south. A
// circuit relation whose ways are mis-oriented says so too.
function turnDirection(points: Point[]): Direction {
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
function simplify(points: Point[], from: number, to: number): number[] {
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
export const onEarth = ([lon, lat]: [number, number]): Place => ({ lat, lon });

/** A distance in metres, kept to the tenth of a metre the survey is held at —
 * and every baseline rendered from it. */
export function roundTenth(n: number): number {
  return Math.round(n * 10) / 10;
}

