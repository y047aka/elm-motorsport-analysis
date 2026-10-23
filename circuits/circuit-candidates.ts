// What OpenStreetMap says a relation is, before anyone draws from it: whether
// a place's tags could name a circuit at all, what a relation's own tags claim
// about itself, how far a probe box reaches, and what an answer says about the
// roles its members carry. `probe-circuit.ts` is the command that asks; this
// is the reading of an answer already got, opening nothing and reaching no
// network, which is what lets it be handed one that was kept.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; what is
// printed here is a derivative of their tags.

import type { OsmRelation, OsmTags, OsmWay, OverpassAnswer } from "./circuit-geometry.ts";
import { polylineMetres } from "./circuit-geometry.ts";

/** A box on the earth, degrees, as Overpass takes it: south, west, north, east. */
export type Box = { s: number; w: number; n: number; e: number };

/** `s,w,n,e` as given, or a `lat,lon` centre widened by the radius: 111.32 km
 * per degree of latitude, and that times the cosine of the parallel for
 * longitude. */
export function bboxOf(place: string, radiusKm: number): Box {
  const numbers = place.split(",").map(Number);
  if (numbers.length === 4 && numbers.every(Number.isFinite)) {
    const [s, w, n, e] = numbers;
    if (s >= n || w >= e) throw new Error(`the box does not open north-east: ${place}`);
    return { s, w, n, e };
  }
  if (numbers.length === 2 && numbers.every(Number.isFinite)) {
    const [lat, lon] = numbers;
    const dLat = radiusKm / 111.32;
    const dLon = radiusKm / (111.32 * Math.cos((lat * Math.PI) / 180));
    return { s: lat - dLat, w: lon - dLon, n: lat + dLat, e: lon + dLon };
  }
  throw new Error(`neither a centre nor a box: ${place}`);
}

/** What the tags say, before any geometry is asked for: what kind of relation
 * it is, what it is called, and the length the tags themselves claim — the
 * Sarthe relation tags its own `distance` as 13.626. */
export function describe(tags: OsmTags): string {
  const parts = [tags.type && `type=${tags.type}`, tags.route && `route=${tags.route}`, tags.sport && `sport=${tags.sport}`]
    .filter(Boolean)
    .join(" ");
  const name = tags.name ?? tags["name:en"] ?? tags.alt_name ?? "(unnamed)";
  const claimed = tags.distance === undefined ? "" : `, tags say ${tags.distance} km`;
  return `${parts}  "${name}"${claimed}`;
}

/** Whether the tags could name a circuit: probed relations are the ones this
 * pipeline could chain, and a road or an administrative boundary catching the
 * box is not. */
export function looksLikeACircuit(tags: OsmTags): boolean {
  if (tags.type === "circuit" || tags.motorsport !== undefined) return true;
  if (tags.highway === "raceway") return true;
  if (String(tags.sport ?? "").startsWith("motor")) return true;
  if (tags.type === "route") {
    return /motor|rally|rac|circ/.test(String(tags.route ?? "")) || Object.keys(tags).some((k) => k.startsWith("raceway:"));
  }
  return false;
}

/** The relation's ways, measured: how many there are and under which roles,
 * and the length of the ones the lap would be chained from -- ways with no
 * role, which is the role the pipeline chains and the kept geometries carry.
 * Ways may overlap or double back at a pit complex, so the sum is an estimate
 * beside the tags' own claim, not a second survey. The answer is one already
 * got; asking for it is the probe's. */
export function measureAnswer(answer: OverpassAnswer, relation: number): string {
  const rel = answer.elements.find((el): el is OsmRelation => el.type === "relation");
  if (!rel) throw new Error(`the answer holds no relation ${relation}`);
  const ways = new Map<number, OsmWay>(
    answer.elements.filter((el): el is OsmWay => el.type === "way").map((w) => [w.id, w]),
  );
  const byRole = new Map<string, { ways: number; metres: number }>();
  const nodeRoles: string[] = [];
  for (const member of rel.members ?? []) {
    if (member.type !== "way") {
      if (member.role) nodeRoles.push(member.role);
      continue;
    }
    const role = member.role || "";
    const entry = byRole.get(role) ?? { ways: 0, metres: 0 };
    entry.ways++;
    entry.metres += polylineMetres(ways.get(member.ref)?.geometry ?? []);
    byRole.set(role, entry);
  }
  const lap = byRole.get("") ?? { ways: 0, metres: 0 };
  const pit = byRole.get("pit_lane") ?? byRole.get("pit");
  const roles = [...byRole.entries()]
    .map(([role, entry]) => `${role === "" ? "(none)" : role}: ${entry.ways} way${entry.ways === 1 ? "" : "s"}`)
    .join(", ");
  const pitNote = pit === undefined ? "" : `, pit ${pit.metres.toFixed(0)} m`;
  return (
    `lap ${lap.metres.toFixed(0)} m over ${lap.ways} unroled way${lap.ways === 1 ? "" : "s"}` +
    `${pitNote}; roles: ${roles}` +
    (nodeRoles.length === 0 ? "" : `; nodes: ${nodeRoles.join(", ")}`)
  );
}
