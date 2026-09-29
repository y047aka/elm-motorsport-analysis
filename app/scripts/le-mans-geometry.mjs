// Writes `Motorsport.Wec.Circuit.LeMans.Geometry`: the Circuit de la Sarthe's
// centreline and pit lane, out of OpenStreetMap's relation for the circuit.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// module written here is a derivative of it.
//
//     node scripts/le-mans-geometry.mjs [overpass.json]
//
// Given a file, reads the Overpass answer out of it rather than asking.
//
// Every point is written as it was surveyed, in WGS84 degrees, with how far round
// the lap it stands. The drawing's metres are not written: Elm projects the
// degrees through the `Motorsport.Circuit.Geodesy.Frame` written beside them, to
// the tenth of a metre the survey is kept to, and the same frame joins a GPS log
// of a car to the lap. So a second circuit's script has to write the same frame,
// out of the two numbers its own projection uses: the parallel it scales
// east-west at, and the north-west corner of what it surveyed.

import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const modulePath = join(repoDir, "package/src/Motorsport/Wec/Circuit/LeMans/Geometry.elm");

const relation = 2126739;
const overpass = "https://overpass-api.de/api/interpreter";
const userAgent = "elm-motorsport-analysis/1.0 (circuit geometry)";

// Al Kamel's circuit maps give the centreline as 13,625.7 m every season from
// 2024 to 2026, and every distance the timing lines are placed at is measured
// along it. OpenStreetMap's ways come to a little less, so the lap is stretched
// to the published length rather than the lines moved.
const lapLength = 13625.7;

// Metres a simplified line may stray from the surveyed one.
const tolerance = 1.0;

async function main() {
  const [file] = process.argv.slice(2);
  const osm = file ? JSON.parse(await readFile(file, "utf8")) : await ask();

  const rel = osm.elements.find((e) => e.type === "relation" && e.id === relation);
  const ways = new Map(osm.elements.filter((e) => e.type === "way").map((w) => [w.id, w]));
  const nodes = new Map(osm.elements.filter((e) => e.type === "node").map((n) => [n.id, n]));
  const start = rel.members.find((m) => m.role === "start-finish").ref;

  const track = chain(rel.members.filter((m) => m.type === "way" && m.role === "").map((m) => ways.get(m.ref)), start);
  const lap = [...rotate(track.slice(0, -1), start), start];
  const pit = chain(rel.members.filter((m) => m.role === "pit_lane").map((m) => ways.get(m.ref)), null);

  const lapNodes = lap.map((id) => nodes.get(id));
  const pitNodes = pit.map((id) => nodes.get(id));
  const { project, parallel } = projection([...lapNodes, ...pitNodes]);
  const lapPoints = lapNodes.map(project);
  const pitPoints = pitNodes.map(project);

  const surveyed = cumulative(lapPoints);
  const stretch = lapLength / surveyed[surveyed.length - 1];
  const metres = surveyed.map((m) => m * stretch);

  const half = Math.floor(lapPoints.length / 2);
  const kept = [
    ...simplify(lapPoints, 0, half).slice(0, -1),
    ...simplify(lapPoints, half, lapPoints.length - 1),
  ];
  const keptPit = simplify(pitPoints, 0, pitPoints.length - 1);

  const all = [...lapPoints, ...pitPoints];
  const minX = Math.min(...all.map((p) => p.x));
  const minY = Math.min(...all.map((p) => p.y));
  const frame = frameOf([...lapNodes, ...pitNodes], project, parallel, minX, minY);

  const onEarth = (node) => ({ lat: node.lat, lon: node.lon });
  const centreline = kept.map((i) => ({ ...onEarth(lapNodes[i]), metres: round(metres[i]) }));
  const pitLane = keptPit.map((i) => onEarth(pitNodes[i]));

  await writeFile(modulePath, elmModule(centreline, pitLane, frame, osm.osm3s?.timestamp_osm_base));
  console.log(
    `centreline: ${centreline.length} points of ${lapPoints.length}, surveyed ${surveyed[surveyed.length - 1].toFixed(1)} m; ` +
      `pit lane: ${pitLane.length} points of ${pitPoints.length}; ` +
      `frame: origin ${frame.origin.lat}, ${frame.origin.lon} parallel ${frame.parallel}`,
  );
}

async function ask() {
  const query = `[out:json][timeout:120];relation(${relation});out body;way(r);out body;node(w);out skel;`;
  const response = await fetch(overpass, {
    method: "POST",
    headers: { "User-Agent": userAgent, "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data: query }),
  });
  if (!response.ok) throw new Error(`Overpass answered ${response.status}`);
  return response.json();
}

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

// Equirectangular about the circuit's own latitude: across 6 km its error is
// far below the tolerance the line is simplified to. `y` runs south, as SVG's
// does, so north is up.
function projection(points) {
  const radius = 6371008.8;
  const parallel = points.reduce((sum, p) => sum + p.lat, 0) / points.length;
  const east = Math.cos(parallel * (Math.PI / 180));
  const project = ({ lat, lon }) => ({
    x: lon * (Math.PI / 180) * radius * east,
    y: -lat * (Math.PI / 180) * radius,
  });
  return { project, parallel };
}

// The frame the drawing's metres are measured in, as Elm reads them: `project`
// above shifts nothing, and the drawing Elm writes is measured from the frame's
// origin -- so that origin has to be the north-west corner of the survey, which
// is where the line this module wrote was drawn. An origin anywhere else moves
// every metre of the drawing off the tenth it is kept to, and every baseline made
// of it with it.
function frameOf(points, project, parallel, minX, minY) {
  const origin = {
    lat: Math.max(...points.map((p) => p.lat)),
    lon: Math.min(...points.map((p) => p.lon)),
  };
  const zero = project(origin);
  if (Math.abs(zero.x - minX) > 1e-9 || Math.abs(zero.y - minY) > 1e-9) {
    throw new Error("the frame's origin does not fall where the drawing's zero is");
  }
  return { origin, parallel };
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

function elmModule(centreline, pitLane, frame, surveyedAt) {
  const lap = centreline.map((p) => `{ lat = ${p.lat}, lon = ${p.lon}, metres = ${p.metres} }`);
  const pit = pitLane.map((p) => `{ lat = ${p.lat}, lon = ${p.lon} }`);
  const list = (items) => `    [ ${items.join("\n    , ")}\n    ]`;
  return `module Motorsport.Wec.Circuit.LeMans.Geometry exposing (LapPoint, PitPoint, centreline, frame, pitLane)

{-| The Circuit de la Sarthe as OpenStreetMap surveys it${surveyedAt ? ` (${surveyedAt})` : ""},
in WGS84 degrees, with how far round the lap each point stands. North is up and
\`y\` runs south in the drawing these degrees are projected into, which
\`Motorsport.Wec.Circuit.LeMans.Layout\` writes. Written by
\`app/scripts/le-mans-geometry.mjs\`; edit that rather than this.

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


{-| The drawing's metres, and a GPS log's, measured on the earth. A sample read
through [\`Geodesy.project\`](Motorsport-Circuit-Geodesy#project) lands among the
points, and [\`Shape.nearest\`](Motorsport-Circuit-Shape#nearest) says how far round
the lap it was.
-}
frame : Frame
frame =
    Geodesy.frame
        { origin = { lat = ${frame.origin.lat}, lon = ${frame.origin.lon} }
        , parallel = ${frame.parallel}
        }


{-| The racing lap from the finish line, clockwise, back to the finish line.
\`metres\` is how far round the lap a point is, stretched to the 13,625.7 m of
Al Kamel's circuit maps. A sample read back off the line is stretched with it,
which is the scale the timing feed counts lap distances in.
-}
centreline : List LapPoint
centreline =
${list(lap)}


{-| From where it leaves the track before the Ford chicane to where it rejoins
it in the Dunlop curve, in the direction it is driven.
-}
pitLane : List PitPoint
pitLane =
${list(pit)}
`;
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
