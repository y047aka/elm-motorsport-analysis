// Writes `Motorsport.Wec.Circuit.LeMans.Geometry`: the Circuit de la Sarthe's
// centreline and pit lane, out of OpenStreetMap's relation for the circuit.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL, and the
// module written here is a derivative of it.
//
//     node scripts/le-mans-geometry.mjs [overpass.json]
//
// Given a file, reads the Overpass answer out of it rather than asking.

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

  const project = projection([...lap, ...pit].map((id) => nodes.get(id)));
  const lapPoints = lap.map((id) => project(nodes.get(id)));
  const pitPoints = pit.map((id) => project(nodes.get(id)));

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
  const at = (p) => ({ x: round(p.x - minX), y: round(p.y - minY) });

  const centreline = kept.map((i) => ({ ...at(lapPoints[i]), metres: round(metres[i]) }));
  const pitLane = keptPit.map((i) => at(pitPoints[i]));

  await writeFile(modulePath, elmModule(centreline, pitLane, osm.osm3s?.timestamp_osm_base));
  console.log(
    `centreline: ${centreline.length} points of ${lapPoints.length}, surveyed ${surveyed[surveyed.length - 1].toFixed(1)} m; ` +
      `pit lane: ${pitLane.length} points of ${pitPoints.length}`,
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
  const lat0 = (points.reduce((sum, p) => sum + p.lat, 0) / points.length) * (Math.PI / 180);
  return ({ lat, lon }) => ({
    x: lon * (Math.PI / 180) * radius * Math.cos(lat0),
    y: -lat * (Math.PI / 180) * radius,
  });
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

function elmModule(centreline, pitLane, surveyedAt) {
  const marks = centreline.map((p) => `{ x = ${p.x}, y = ${p.y}, metres = ${p.metres} }`);
  const points = pitLane.map((p) => `{ x = ${p.x}, y = ${p.y} }`);
  const list = (items) => `    [ ${items.join("\n    , ")}\n    ]`;
  return `module Motorsport.Wec.Circuit.LeMans.Geometry exposing (centreline, pitLane)

{-| The Circuit de la Sarthe as OpenStreetMap surveys it${surveyedAt ? ` (${surveyedAt})` : ""}, in
metres, with north up and \`y\` running south. Written by
\`app/scripts/le-mans-geometry.mjs\`; edit that rather than this.

Map data © OpenStreetMap contributors, under the Open Database License.

@docs centreline, pitLane

-}

import Motorsport.Circuit.Shape exposing (Mark, Point)


{-| The racing lap from the finish line, clockwise, back to the finish line.
\`metres\` is how far round the lap a point is, stretched to the 13,625.7 m of
Al Kamel's circuit maps.
-}
centreline : List Mark
centreline =
${list(marks)}


{-| From where it leaves the track before the Ford chicane to where it rejoins
it in the Dunlop curve, in the direction it is driven.
-}
pitLane : List Point
pitLane =
${list(points)}
`;
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
