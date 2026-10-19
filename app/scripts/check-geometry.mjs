// Whether every generated circuit module still matches the surveyed answer it was
// written from.
//
//     node scripts/check-geometry.mjs
//
// Writes each module out of its circuit's fixture again and compares, which needs
// no network and no OpenStreetMap: the fixture holds the answer, and the pipeline is
// a pure function of it. A difference is one of two things -- a module edited by
// hand, which the generator overwrites, or a fixture refreshed with `--refresh`,
// which the module has to follow and every tracker baseline with it.
//
// The survey each module holds was taken from a database that keeps moving, so
// without this a module could silently stop being the answer it claims to be: its
// metres are what the tracker draws cars at, the drawn places are held to a tenth of
// a metre, and every VRT baseline was rendered at the tenths it said.
//
// OpenStreetMap data is © OpenStreetMap contributors, under the ODbL.

import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { answerOf, lapOf, moduleText } from "./circuit-geometry.mjs";
import { circuit as leMans } from "./le-mans-geometry.mjs";
import { circuit as cota } from "./cota-geometry.mjs";

const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const circuits = [leMans, cota];

/** Show the difference the way a person reads one, if git can. */
function showDiff(circuit, regenerated) {
  const diff = spawnSync(
    "git",
    [
      "diff",
      "--no-index",
      "--text",
      "--unified=1",
      "--color=never",
      "--src-prefix=on disk: ",
      "--dst-prefix=from the fixture: ",
      "--",
      circuit.path,
      regenerated,
    ],
    { cwd: repoDir, stdio: "inherit" },
  );
  if (diff.status !== 1) console.log("  (git showed nothing; the files differ in full.)");
}

/** One circuit's verdict: whether the module on disk is the one its fixture writes. */
async function check(circuit, scratch) {
  const geometry = lapOf(await answerOf(circuit, {}), circuit);
  const written = moduleText(circuit, geometry);
  const onDisk = await readFile(join(repoDir, circuit.path), "utf8");

  if (onDisk === written) {
    console.log(
      `${circuit.path}: ${geometry.centreline.length} points of ${geometry.counts.lap}, ` +
        `surveyed ${geometry.surveyedLength.toFixed(1)} m, as its fixture holds (${geometry.surveyedAt ?? "no survey time"}).`,
    );
    return 0;
  }

  const at = join(scratch, `${circuit.name}.elm`);
  await writeFile(at, written);
  console.log(`${circuit.path}: is not what ${circuit.fixture} writes`);
  showDiff(circuit, at);
  console.log(`  Write it with \`nix run .#geometry-${circuit.name}\`.\n`);
  return 1;
}

const scratch = await mkdtemp(join(tmpdir(), "geometry-check-"));
let drifted = 0;
for (const circuit of circuits) {
  drifted += await check(circuit, scratch);
}

if (drifted > 0) {
  console.log(
    `${drifted} of ${circuits.length} circuit modules are not what their fixtures say. ` +
      "A module whose points moved is a different drawing, and every tracker baseline " +
      "moves with it: `nix run .#update-snapshots-ci`.",
  );
  process.exitCode = 1;
}
