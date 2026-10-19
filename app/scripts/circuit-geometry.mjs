// The pipeline every circuit's geometry module is written by: take a relation's
// surveyed points, chain its ways into a lap, stretch the lap to the length the
// circuit publishes, simplify it, and write the Elm module.
//
// One file per circuit calls this with its own relation, its own published lap
// length and its own docstring prose. What it writes is the same shape every
// time -- WGS84 degrees, how far round the lap each stands, and the
// `Motorsport.Circuit.Geodesy.Frame` to project them through -- so a circuit is
// a config here and a `Layout` module on the Elm side.
//
//     node scripts/<circuit>-geometry.mjs [overpass.json]
//
// Given a file, reads the Overpass answer out of it rather than asking -- which is how
// a module is re-written without OpenStreetMap, and how an answer can be kept if the
// survey instant it holds is worth keeping.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and every
// module written here is a derivative of it.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const overpass = "https://overpass-api.de/api/interpreter";
const userAgent = "elm-motorsport-analysis/1.0 (circuit geometry)";

// Metres a simplified line may stray from the surveyed one.
const tolerance = 1.0;

// The earth every drawing is measured on: the same sphere
// `Motorsport.Circuit.Geodesy` projects through.
const radius = 6371008.8;

/**
 * A circuit: where its geometry is surveyed from, what the lap is stretched to,
 * and the words the generated module is documented with.
 *
 * `finishRole` names the relation member the lap is measured from. `timingLine`
 * is where it stands on the earth as the circuit itself publishes it, in which
 * case a run checks the role answered to; a relation may tag several lines and
 * pick the wrong one out of them without failing a build.
 *
 * @typedef {object} Circuit
 * @property {number} relation
 * @property {string} finishRole
 * @property {{ lat: number, lon: number, within?: number }} [timingLine]
 * @property {number} lapLength
 * @property {string} module    e.g. `Motorsport.Wec.Circuit.Cota.Geometry`
 * @property {string} path      the module's file, from the repository root
 * @property {string} layout    the Elm module that draws it, named in the header
 * @property {string} script    this file, named in the header
 * @property {string} survey    e.g. `The Circuit of the Americas`
 * @property {string} centrelineDoc
 * @property {string} pitLaneDoc
 */

/** Whether the module named is the script the process was started from, as
 * against a config another script imported to read a published length out of.
 * `import.meta.url` is the caller's own and not this file's, so it is passed in:
 * read from here it would answer for `circuit-geometry.mjs`, which every circuit's
 * script imports and none enters. */
export function isEntry(moduleUrl) {
  return pathToFileURL(process.argv[1] ?? "").href === moduleUrl;
}

/** Write the circuit's module. `argv` is the script's own, whose first entry may name
 * a file to read the Overpass answer out of rather than asking.
 *
 * Asking is the default and it does fail: Overpass answers a busy runner with a 502 or
 * a 504, so repeat a run rather than trusting the first. What comes back is a survey
 * taken *now*, so the metres written are today's line -- and the visual tests only show
 * a survey that moved by metres or more, which is why a regeneration is read as a diff
 * and not as a rendering.
 */
export async function main(circuit, argv) {
  try {
    const [file] = argv;
    await writeModule(circuit, lapOf(await answer(circuit.relation, file), circuit));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

/** The answer from a file if one was given, and from OpenStreetMap if not. */
export async function answer(relation, file) {
  return file ? JSON.parse(await readFile(file, "utf8")) : ask(relation);
}

/** The Overpass answer for one relation: its ways with their tags, and nodes. */
export async function ask(relation) {
  const query = `[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;`;
  const response = await fetch(overpass, {
    method: "POST",
    headers: { "User-Agent": userAgent, "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data: query }),
  });
  if (!response.ok) throw new Error(`Overpass answered ${response.status}`);
  return response.json();
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

  const track = chain(rel.members.filter((m) => m.type === "way" && m.role === "").map((m) => ways.get(m.ref)), start);
  const lap = [...rotate(track.slice(0, -1), start), start];
  const pit = chain(rel.members.filter((m) => m.role === "pit_lane").map((m) => ways.get(m.ref)), null);

  const lapNodes = lap.map((id) => nodes.get(id));
  const pitNodes = pit.map((id) => nodes.get(id));
  const { project, parallel } = projection([...lapNodes, ...pitNodes]);
  const lapPoints = lapNodes.map(project);
  const pitPoints = pitNodes.map(project);

  const surveyed = cumulative(lapPoints);
  const stretch = circuit.lapLength / surveyed[surveyed.length - 1];
  const metres = surveyed.map((m) => m * stretch);

  const half = Math.floor(lapPoints.length / 2);
  const kept = [
    ...simplify(lapPoints, 0, half).slice(0, -1),
    ...simplify(lapPoints, half, lapPoints.length - 1),
  ];
  const keptPit = simplify(pitPoints, 0, pitPoints.length - 1);

  const frame = frameOf([...lapNodes, ...pitNodes], parallel);
  const onEarth = (node) => ({ lat: node.lat, lon: node.lon });

  return {
    centreline: kept.map((i) => ({ ...onEarth(lapNodes[i]), metres: round(metres[i]) })),
    pitLane: keptPit.map((i) => onEarth(pitNodes[i])),
    frame,
    surveyedAt: osm.osm3s?.timestamp_osm_base,
    counts: { kept: kept.length, lap: lapPoints.length, pit: keptPit.length, of: pitPoints.length },
    surveyedLength: surveyed[surveyed.length - 1],
  };
}

/** Write the module, and say what was read out of the answer. */
export async function writeModule(circuit, geometry) {
  const path = join(repoDir, circuit.path);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, elmModule(circuit, geometry));
  console.log(
    `centreline: ${geometry.centreline.length} points of ${geometry.counts.lap}, surveyed ${geometry.surveyedLength.toFixed(1)} m; ` +
      `pit lane: ${geometry.pitLane.length} points of ${geometry.counts.of}; ` +
      `frame: origin ${geometry.frame.origin.lat}, ${geometry.frame.origin.lon} parallel ${geometry.frame.parallel}`,
  );
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
  const distance = (node) =>
    Math.hypot(
      (node.lat - circuit.timingLine.lat) * degreesToMetres,
      (node.lon - circuit.timingLine.lon) * degreesToMetres * Math.cos((node.lat * Math.PI) / 180),
    );

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

const degreesToMetres = (Math.PI / 180) * radius;

// The relation lists its ways in no particular order, and a way open to traffic
// both ways may be drawn against the direction of the race. A oneway way is
// drawn the way it is driven, so the chain follows those and turns the others.
function chain(members, start) {
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
  const left = segments.filter((s) => !used.has(s.id)).map((s) => s.id);
  if (left.length > 0) throw new Error(`ways left out of the chain: ${left.join(", ")}`);
  if (start !== null && ids.at(-1) !== ids[0]) throw new Error("the lap does not close");
  return ids;
}

function rotate(ids, start) {
  const i = ids.indexOf(start);
  return [...ids.slice(i), ...ids.slice(0, i)];
}

// Equirectangular about the circuit's own latitude: across the few km a circuit
// covers its error is far below the tolerance the line is simplified to. `y`
// runs south, as SVG's does, so north is up.
function projection(points) {
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

function cumulative(points) {
  const out = [0];
  for (let i = 1; i < points.length; i++) {
    out.push(out[i - 1] + Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y));
  }
  return out;
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

function round(n) {
  return Math.round(n * 10) / 10;
}

function elmModule(circuit, geometry) {
  const lap = geometry.centreline.map((p) => `{ lat = ${p.lat}, lon = ${p.lon}, metres = ${p.metres} }`);
  const pit = geometry.pitLane.map((p) => `{ lat = ${p.lat}, lon = ${p.lon} }`);
  const list = (items) => `    [ ${items.join("\n    , ")}\n    ]`;
  const surveyedAt = geometry.surveyedAt ? ` (${geometry.surveyedAt})` : "";
  return `module ${circuit.module} exposing (LapPoint, PitPoint, centreline, frame, pitLane)

{-| ${circuit.survey} as OpenStreetMap surveys it${surveyedAt},
in WGS84 degrees, with how far round the lap each point stands. North is up and
\`y\` runs south in the drawing these degrees are projected into, which
\`${circuit.layout}\` writes. Written by
\`${circuit.script}\`; edit that rather than this.

Map data © OpenStreetMap contributors, under the Open Database License.

@docs LapPoint, PitPoint, centreline, frame, pitLane

-}

import Motorsport.Circuit.Geodesy as Geodesy exposing (Frame)


{-| A point of the lap: where it stands on the earth, and how far round the lap it
is.
-}
type alias LapPoint =
    { lat : Float
    , lon : Float
    , metres : Float
    }


{-| Where the pit lane stands on the earth.
-}
type alias PitPoint =
    { lat : Float
    , lon : Float
    }


{-| The drawing's metres measured on the earth: every point below is where
[\`Geodesy.project\`](Motorsport-Circuit-Geodesy#project) puts it in this frame.
-}
frame : Frame
frame =
    Geodesy.frame
        { origin = { lat = ${geometry.frame.origin.lat}, lon = ${geometry.frame.origin.lon} }
        , parallel = ${geometry.frame.parallel}
        }


{-| ${circuit.centrelineDoc}
-}
centreline : List LapPoint
centreline =
${list(lap)}


{-| ${circuit.pitLaneDoc}
-}
pitLane : List PitPoint
pitLane =
${list(pit)}
`;
}
