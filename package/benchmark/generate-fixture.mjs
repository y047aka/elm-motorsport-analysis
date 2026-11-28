#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// Whole rather than bounded: half distance is the frame `PerFrameBenchmark` is
// about, and a bound would move it.
//
// 2025's COTA is one of the two rounds a checkout keeps, so nothing has to be run
// before this reads. `--round=` names another, whose files a run has to write out
// first.
const { round } = {
  round: "2025/cota_6h",
  ...Object.fromEntries(
    process.argv.slice(2).map((arg) => {
      const [key, value] = arg.replace(/^--/, "").split("=");
      return [key, value];
    })
  ),
};

const here = dirname(fileURLToPath(import.meta.url));
const summarySource = resolve(here, `../../app/static/wec/${round}.json`);
const lapsSource = resolve(here, `../../app/static/wec/${round}_laps.jsonl`);
const target = resolve(here, "Fixture/Generated.elm");

const read = (path) => {
  try {
    return readFileSync(path, "utf8");
  } catch (cause) {
    throw new Error(
      `${relative(resolve(here, "../.."), path)} is not there, and ${round} is not a round a checkout keeps. ` +
        `A run writes it out:\n\n    nix run .#cli-export -- --export-only ${round}\n`,
      { cause }
    );
  }
};

const summary = read(summarySource);
const jsonl = read(lapsSource);

// An Elm `"""` literal is raw only in that it spans lines: `"""` still ends it,
// and a backslash still opens an escape. Either would reach Elm as something
// other than what is on disk, so neither is carried through.
for (const [path, contents] of [[summarySource, summary], [lapsSource, jsonl]]) {
  const hazard = ['"""', "\\"].find((s) => contents.includes(s));
  if (hazard) {
    throw new Error(`Source holds ${hazard}, which an Elm raw string literal would not carry through: ${path}`);
  }
}

const from = (path) => relative(resolve(here, "../.."), path);

const elm = `module Fixture.Generated exposing (race)

{-| Auto-generated from ${from(summarySource)} and ${from(lapsSource)}.
Do not edit by hand. Run \`node generate-fixture.mjs\` to regenerate.
-}

import Fixture.Json as Fixture
import Motorsport.Race exposing (Race)


race : Race
race =
    Fixture.decode { summary = rawSummary, laps = rawJsonl }


rawSummary : String
rawSummary =
    """${summary}"""


rawJsonl : String
rawJsonl =
    """${jsonl}"""
`;

mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, elm);
console.log(
  `Wrote ${target}: ${round}, ${jsonl.length.toLocaleString()} chars of JSON Lines ` +
    `(${(elm.length / 1e6).toFixed(1)}MB of Elm source)`
);
