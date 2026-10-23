// The first question about a circuit nobody has surveyed yet: which relation
// OpenStreetMap holds it as. Prints each candidate whole — its tags, its member
// ways measured, its roles counted — so the relation is picked from an answer
// rather than a name: around Le Mans the full 13.6 km circuit and the 4.4 km
// Grand Prix circuit both stand, and the measured lap is what tells them apart.
//
//     node circuits/probe-circuit.ts <lat>,<lon> [...] [--radius <km>]
//     node circuits/probe-circuit.ts <south>,<west>,<north>,<east> [...]
//
// A centre is widened into a box by --radius, 5 km unless named otherwise; four
// numbers are the box itself, which is what to give when the circuit's own
// relation spans more. Candidates are the circuit, motor-sport and raceway
// relations the box holds; each likely one is then asked again for its ways'
// geometry. Nothing is written: the report goes to a human, and the pipeline
// begins once a config names the relation the report picked.
//
// This is the asking; what an answer means — the box a place widens to, which
// tags could name a circuit, what a relation's roles measure — is
// `circuit-candidates.ts`, which reaches no network and is what the tests read
// a kept answer with.

import { askOverpass, reason, sleep, valueOf } from "./circuit-geometry.ts";
import { bboxOf, describe, looksLikeACircuit, measureAnswer } from "./circuit-candidates.ts";

// How far a candidate's probed ways may run before the report gives up on them;
// a relation this box catches that is not a circuit is usually a road or an
// administrative boundary.
const probeLimit = 10;

async function main(argv: string[]): Promise<void> {
  const radiusKm = Number(valueOf(argv, "--radius") || 5);
  const places = argv.filter((a) => !a.startsWith("--"));
  if (places.length === 0 || !Number.isFinite(radiusKm)) {
    console.error("usage: probe-circuit.ts <lat>,<lon> [...] [--radius <km>], or <south>,<west>,<north>,<east> [...]");
    process.exitCode = 1;
    return;
  }
  for (const place of places) {
    await probe(place, radiusKm);
    await sleep(3000);
  }
}

async function probe(place: string, radiusKm: number): Promise<void> {
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
      console.log(`      probing failed: ${reason(error)}`);
    }
    await sleep(1500);
  }
}

/** The relation's ways, asked for and measured: the asking is this file's, the
 * reading of the answer is `circuit-candidates.ts`'s. */
async function measure(relation: number): Promise<string> {
  const answer = await askOverpass(`[out:json][timeout:90];relation(${relation});out body;way(r);out geom;`);
  return measureAnswer(answer, relation);
}

main(process.argv.slice(2)).catch((error) => {
  console.error(reason(error));
  process.exitCode = 1;
});
