#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const source = resolve(here, "../../app/static/wec/2025/fuji_6h_laps.json");
const target = resolve(here, "Fixture/Generated.elm");

const json = readFileSync(source, "utf8");

if (json.includes('"""')) {
  throw new Error(`Source JSON contains """, which would break the Elm raw string literal: ${source}`);
}

const elm = `module Fixture.Generated exposing (cars)

{-| Auto-generated from ${relative(resolve(here, "../.."), source)}.
Do not edit by hand. Run \`node generate-fixture.mjs\` to regenerate.
-}

import Fixture.Json as Fixture
import Motorsport.Race.Car exposing (Car)


cars : List Car
cars =
    Fixture.decode rawJson


rawJson : String
rawJson =
    """${json}"""
`;

mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, elm);
console.log(`Wrote ${target} (${json.length.toLocaleString()} chars of JSON)`);
