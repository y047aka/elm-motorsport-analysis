// The regeneration fence: re-runs the geometry pipeline over each circuit's
// kept Overpass answer — the survey a kept geometry was judged from, kept as
// the runner served it, whose degrees cannot move — and fails unless it
// reproduces the geometry the app serves. A run over the answer that does not
// reproduce the geometry moved the degrees in the code; why that is the check
// no Elm test can be is `circuits/README.md`.
//
//     node circuits/regenerate-geometry.ts [<circuit> ...] [--write | --freeze]
//
// `surveyed_at` is the one property exempt from the fence: it stamps which
// answer a file was written from rather than what the drawing is made of, and
// it is the one property a live regeneration must move while every degree
// stands still. The Elm side reads neither it nor `surveyed_length_m`; the
// fence reads both.
//
// --write re-lays the geometry files from the kept answer — where a changed
// writer lands its bytes with no survey moved. --freeze asks OpenStreetMap now
// and keeps the answer and the geometry as one reading of a regeneration. A
// circuit's geometry script never reaches the answer by default: a
// regeneration that silently answered itself from the frozen survey would stop
// meaning what it says.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

import type { Circuit } from "./circuit-geometry.ts";
import { ask, geoJsonString, lapOf, repoDir } from "./circuit-geometry.ts";
import { circuits, keptAnswer } from "./registry.ts";

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const write = argv.includes("--write");
  const freeze = argv.includes("--freeze");
  if (write && freeze) throw new Error("--write and --freeze ask for opposite things: the kept answer, and a fresh survey.");
  const named = argv.filter((a) => !a.startsWith("--"));
  for (const name of named.length > 0 ? named : Object.keys(circuits)) {
    if (!(name in circuits)) {
      throw new Error(`no circuit is surveyed under '${name}': known are ${Object.keys(circuits).join(", ")}`);
    }
    await reRun(circuits[name], write, freeze);
  }
}

async function reRun(circuit: Circuit, write: boolean, freeze: boolean): Promise<void> {
  const path = keptAnswer(circuit);

  let answer;
  if (freeze) {
    answer = await ask(circuit.relation);
  } else {
    try {
      answer = JSON.parse(await readFile(path, "utf8"));
    } catch (error) {
      if ((error as { code?: string }).code !== "ENOENT") throw error;
      console.log(`${circuit.slug}: no kept answer yet — --freeze asks OpenStreetMap and keeps one.`);
      return;
    }
  }

  const written = geoJsonString(circuit, lapOf(answer, circuit));
  if (write || freeze) {
    if (freeze) {
      await mkdir(dirname(path), { recursive: true });
      await writeFile(path, JSON.stringify(answer));
    }
    await writeFile(join(repoDir, circuit.geojson), written);
    console.log(`${circuit.slug}: geometry written from ${freeze ? "a fresh survey" : "the kept answer"}`);
    return;
  }

  const drift = driftOf(JSON.parse(written), JSON.parse(await readFile(join(repoDir, circuit.geojson), "utf8")));
  if (drift.length === 0) {
    console.log(`${circuit.slug}: reproduces the kept geometry, every fenced property exactly`);
    return;
  }
  console.log(`${circuit.slug}: the kept geometry is not what the kept answer draws`);
  for (const line of drift) console.log(`  ${line}`);
  process.exitCode = 1;
}

// How one geometry file's data answers to another's, feature by feature and
// property by property. The comparison is of parsed data, not bytes: what the
// fence answers for is the drawing, and the writer's layout is allowed to
// change between the file and this reading — --write is where it lands.
function driftOf(fresh: any, kept: any): string[] {
  const drift: string[] = [];
  const roles = [...new Set([...fresh.features, ...kept.features].map((f: any) => f.properties?.role))];
  for (const role of roles) {
    const a = fresh.features.find((f: any) => f.properties?.role === role);
    const b = kept.features.find((f: any) => f.properties?.role === role);
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

function firstDiff(a: any[], b: any[]): number {
  for (let at = 0; at < Math.max(a.length, b.length); at++) {
    if (JSON.stringify(a[at]) !== JSON.stringify(b[at])) return at;
  }
  return -1;
}

const shown = (value: unknown) => (value === undefined ? "absent" : JSON.stringify(value));
