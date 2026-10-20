// The regeneration fence: re-runs the geometry pipeline over each circuit's
// kept Overpass answer and fails unless it reproduces the geometry the app
// serves.
//
//     node scripts/regenerate-geometry.mjs [<circuit> ...] [--write | --freeze]
//
// The answer under `scripts/geometry/` is the survey a kept geometry was
// judged from, kept as the runner served it — the pipeline's frozen input. Its
// degrees cannot move, so a run over it that does not reproduce the geometry
// moved them in the code. This is the check no Elm test can be:
// `circuit-geometry.mjs` stretches whatever degrees it is given, so a survey
// swapped under a drawing reads exactly as the drawing expects.
//
// `surveyed_at` is the one property exempt from the fence: it stamps which
// answer a file was written from rather than what the drawing is made of, and
// it is the one property a live regeneration must move while every degree
// stands still. The Elm side reads neither it nor `surveyed_length_m`; the
// fence reads both, so a file cannot quietly stop answering to the survey it
// claims.
//
// --write re-lays the geometry files from the kept answer — where a changed
// writer lands its bytes with no survey moved. --freeze asks OpenStreetMap now
// and keeps the answer and the geometry as one reading of a regeneration. A
// circuit's geometry script never reaches the answer by default: a
// regeneration that silently answered itself from the frozen survey would stop
// meaning what it says.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { ask, geoJsonString, lapOf } from "./circuit-geometry.mjs";

const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const circuits = {
  // Keyed by the circuit word, as the atlas table keys itself: `script` is the
  // one that surveys the circuit, `answer` the kept Overpass answer beside this
  // file — evidence a check is made against, never bytes the app asks for.
  cota: { script: "./cota-geometry.mjs", answer: "app/scripts/geometry/cota.overpass.json" },
  le_mans: { script: "./le-mans-geometry.mjs", answer: "app/scripts/geometry/le_mans.overpass.json" },
};

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

async function main() {
  const argv = process.argv.slice(2);
  const write = argv.includes("--write");
  const freeze = argv.includes("--freeze");
  if (write && freeze) throw new Error("--write and --freeze ask for opposite things: the kept answer, and a fresh survey.");
  const named = argv.filter((a) => !a.startsWith("--"));
  for (const name of named.length > 0 ? named : Object.keys(circuits)) {
    if (!(name in circuits)) {
      throw new Error(`no answer is registered for '${name}': known are ${Object.keys(circuits).join(", ")}`);
    }
    await reRun(name, write, freeze);
  }
}

async function reRun(name, write, freeze) {
  const entry = circuits[name];
  const { circuit } = await import(new URL(entry.script, import.meta.url));
  const path = join(repoDir, entry.answer);

  let answer;
  if (freeze) {
    answer = await ask(circuit.relation);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, JSON.stringify(answer));
  } else {
    try {
      answer = JSON.parse(await readFile(path, "utf8"));
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      console.log(`${name}: no kept answer yet — --freeze asks OpenStreetMap and keeps one.`);
      return;
    }
  }

  const written = geoJsonString(circuit, lapOf(answer, circuit));
  if (write || freeze) {
    await writeFile(join(repoDir, circuit.geojson), written);
    console.log(`${name}: geometry written from ${freeze ? "a fresh survey" : "the kept answer"}`);
    return;
  }

  const drift = driftOf(JSON.parse(written), JSON.parse(await readFile(join(repoDir, circuit.geojson), "utf8")));
  if (drift.length === 0) {
    console.log(`${name}: reproduces the kept geometry, every fenced property exactly`);
    return;
  }
  console.log(`${name}: the kept geometry is not what the kept answer draws`);
  for (const line of drift) console.log(`  ${line}`);
  process.exitCode = 1;
}

// How one geometry file's data answers to another's, feature by feature and
// property by property. The comparison is of parsed data, not bytes: what the
// fence answers for is the drawing, and the writer's layout is allowed to
// change between the file and this reading — --write is where it lands.
function driftOf(fresh, kept) {
  const drift = [];
  const roles = [...new Set([...fresh.features, ...kept.features].map((f) => f.properties?.role))];
  for (const role of roles) {
    const a = fresh.features.find((f) => f.properties?.role === role);
    const b = kept.features.find((f) => f.properties?.role === role);
    if (!a || !b) {
      drift.push(`${role}: only ${a ? "the regeneration" : "the kept file"} holds it`);
      continue;
    }
    if (JSON.stringify(a.geometry) !== JSON.stringify(b.geometry)) {
      drift.push(`${role}: the line's points differ at point ${firstDiff(a.geometry.coordinates, b.geometry.coordinates)}`);
    }
    for (const key of new Set([...Object.keys(a.properties), ...Object.keys(b.properties)])) {
      if (key === "surveyed_at") continue;
      if (JSON.stringify(a.properties[key]) !== JSON.stringify(b.properties[key])) {
        drift.push(`${role}: ${key} is ${shown(b.properties[key])} in the file, ${shown(a.properties[key])} from the answer`);
      }
    }
  }
  return drift;
}

function firstDiff(a, b) {
  for (let at = 0; at < Math.max(a.length, b.length); at++) {
    if (JSON.stringify(a[at]) !== JSON.stringify(b[at])) return at;
  }
  return -1;
}

const shown = (value) => (value === undefined ? "absent" : JSON.stringify(value));
