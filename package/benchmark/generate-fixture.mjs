#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const summarySource = resolve(here, "../../app/static/wec/2025/fuji_6h.json");
const lapsSource = resolve(here, "../../app/static/wec/2025/fuji_6h_laps.jsonl");
const target = resolve(here, "Fixture/Generated.elm");

const summary = readFileSync(summarySource, "utf8");
const jsonl = readFileSync(lapsSource, "utf8");

for (const [path, contents] of [[summarySource, summary], [lapsSource, jsonl]]) {
  if (contents.includes('"""')) {
    throw new Error(`Source holds """, which would break the Elm raw string literal: ${path}`);
  }
}

const from = (path) => relative(resolve(here, "../.."), path);

const elm = `module Fixture.Generated exposing (cars)

{-| Auto-generated from ${from(summarySource)} and ${from(lapsSource)}.
Do not edit by hand. Run \`node generate-fixture.mjs\` to regenerate.
-}

import Fixture.Json as Fixture
import Motorsport.Race.Car exposing (Car)


cars : List Car
cars =
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
