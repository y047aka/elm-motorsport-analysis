#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const summarySource = resolve(here, "../../app/static/wec/2025/fuji_6h.json");
const lapsSource = resolve(here, "../../app/static/wec/2025/fuji_6h_laps.jsonl");
const target = resolve(here, "Fixture/Generated.elm");

// A checkout keeps 2025's Le Mans and no other round's files, so this one is
// written by a run before it can be read. Whole rather than bounded, since half
// distance is the frame the benchmark is about and a bound would move it.
const read = (path) => {
  try {
    return readFileSync(path, "utf8");
  } catch (cause) {
    throw new Error(
      `${relative(resolve(here, "../.."), path)} is not there. The round it holds ` +
        `is not one a checkout keeps, so a run has to write it first:\n\n` +
        `    nix run .#cli-export -- --export-only 2025/fuji_6h\n`,
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
console.log(`Wrote ${target} (${jsonl.length.toLocaleString()} chars of JSON Lines)`);
