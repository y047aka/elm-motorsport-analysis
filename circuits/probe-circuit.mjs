// The first question about a circuit nobody has surveyed yet: which relation
// OpenStreetMap holds it as. A circuit's config for the pipeline names one
// relation, the role of its finish line and the lap length the circuit
// publishes; this asks what stands at a place on earth before any of that
// exists, and prints each candidate whole — its tags, its member ways measured,
// its roles counted — so the relation is picked from an answer. The measured
// lap is what discriminates: around Le Mans the full 13.6 km circuit and the
// 4.4 km Grand Prix circuit both stand, and a name alone does not tell them
// apart.
//
//     node circuits/probe-circuit.mjs <lat>,<lon> [...] [--radius <km>]
//     node circuits/probe-circuit.mjs <south>,<west>,<north>,<east> [...]
//
// A centre is widened into a box by --radius, 5 km unless named otherwise;
// four numbers are the box itself, which is what to give when the circuit's own
// relation spans more. Candidates are the circuit, motor-sport and raceway
// relations the box holds; each likely one is then asked again for its ways'
// geometry. Nothing is written: the report goes to a human, and the pipeline
// begins once a config names the relation the report picked.

import { askOverpass, polylineMetres } from "./circuit-geometry.mjs";

const pause = (ms) => new Promise((done) => setTimeout(done, ms));

// How far a candidate's probed ways may run before the report gives up on them;
// a relation this box catches that is not a circuit is usually a road or an
// administrative boundary.
const probeLimit = 10;

async function main(argv) {
  const radiusKm = Number(valueOf(argv, "--radius") || 5);
  const places = argv.filter((a) => !a.startsWith("--"));
  if (places.length === 0 || !Number.isFinite(radiusKm)) {
    console.error("usage: probe-circuit.mjs <lat>,<lon> [...] [--radius <km>], or <south>,<west>,<north>,<east> [...]");
    process.exitCode = 1;
    return;
  }
  for (const place of places) {
    await probe(place, radiusKm);
    await pause(3000);
  }
}

function valueOf(argv, flag) {
  const at = argv.indexOf(flag);
  return at === -1 ? null : argv[at + 1] || "";
}

async function probe(place, radiusKm) {
  const box = bboxOf(place, radiusKm);
  const bounds = `${box.s},${box.w},${box.n},${box.e}`;
  console.log(`\n== ${place} (bbox ${bounds})`);
  const found = await askOverpass(
    `[out:json][timeout:90];(` +
      `relation["type"="circuit"](${bounds});` +
      `relation["sport"~"^motor"](${bounds});` +
      `relation["motorsport"](${bounds});` +
      `relation["route"~"^(raceway|motorsport|racing)$"](${bounds});` +
      `relation["highway"="raceway"](${bounds});` +
      `);out tags;`,
  );
  const elements = found.elements ?? [];
  if (elements.length === 0) {
    console.log(
      "  nothing tagged as a circuit, a motor-sport route or a raceway here. Either the box misses the " +
        "circuit -- widen it -- or OpenStreetMap holds the ground untagged, and this pipeline, which chains a " +
        "relation's ways, has nothing to start from.",
    );
    return;
  }

  let probed = 0;
  for (const el of elements) {
    const tags = el.tags ?? {};
    console.log(`  relation ${el.id}  ${describe(tags)}`);
    if (!looksLikeACircuit(tags)) {
      console.log("      not probed: tagged as neither a circuit, a motor-sport route nor a raceway");
      continue;
    }
    if (probed >= probeLimit) {
      console.log("      not probed: the limit of probed candidates is used up");
      continue;
    }
    probed++;
    try {
      console.log(`      ${await measure(el.id)}`);
    } catch (error) {
      console.log(`      probing failed: ${error.message}`);
    }
    await pause(1500);
  }
}

/** What the tags say, before any geometry is asked for: what kind of relation
 * it is, what it is called, and the length the tags themselves claim — the
 * Sarthe relation tags its own `distance` as 13.626. */
function describe(tags) {
  const parts = [tags.type && `type=${tags.type}`, tags.route && `route=${tags.route}`, tags.sport && `sport=${tags.sport}`]
    .filter(Boolean)
    .join(" ");
  const name = tags.name ?? tags["name:en"] ?? tags.alt_name ?? "(unnamed)";
  const claimed = tags.distance === undefined ? "" : `, tags say ${tags.distance} km`;
  return `${parts}  "${name}"${claimed}`;
}

function looksLikeACircuit(tags) {
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
 * beside the tags' own claim, not a second survey. */
async function measure(relation) {
  const answer = await askOverpass(`[out:json][timeout:90];relation(${relation});out body;way(r);out geom;`);
  const rel = answer.elements.find((el) => el.type === "relation");
  const ways = new Map(answer.elements.filter((el) => el.type === "way").map((w) => [w.id, w]));
  const byRole = new Map();
  const nodeRoles = [];
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

/** `s,w,n,e` as given, or a `lat,lon` centre widened by the radius: 111.32 km
 * per degree of latitude, and that times the cosine of the parallel for
 * longitude. */
function bboxOf(place, radiusKm) {
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

main(process.argv.slice(2)).catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
