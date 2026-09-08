#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// A fixture of its own rather than `generate-fixture.mjs`'s, which is a whole
// round because `PerFrameBenchmark` reads half distance off it. This one is
// bounded, since the laps are embedded twice and every lap of Le Mans would be
// fifty megabytes of Elm source.
//
// 2025's Le Mans is the round a checkout keeps, so nothing has to be run first.
// It is also the only round with mini-sectors and the one with the most laps.
const { round, laps: lapCap } = {
  round: "2025/le_mans_24h",
  laps: 40,
  ...Object.fromEntries(
    process.argv.slice(2).map((arg) => {
      const [key, value] = arg.replace(/^--/, "").split("=");
      return [key, key === "laps" ? Number(value) : value];
    })
  ),
};

const here = dirname(fileURLToPath(import.meta.url));
const summarySource = resolve(here, `../../app/static/wec/${round}.json`);
const lapsSource = resolve(here, `../../app/static/wec/${round}_laps.jsonl`);
const target = resolve(here, "Fixture/Positions.elm");

const summary = readFileSync(summarySource, "utf8");

// The bound is on the lap number rather than on the cars: `assignPositions`
// costs the laps times the cars, so a smaller field would be a different race.
//
// It is low because elm-benchmark runs a benchmark until it has a sample it
// trusts, and a round of laps is far too much work per run to get one. The
// bound is carried into the fixture so that `Benchmark.scale` can take it and
// the halves of it, which is how the shape is read without running twice.
const lines = readFileSync(lapsSource, "utf8").split("\n").filter((line) => line.length > 0);
const kept = lines.filter((line) => JSON.parse(line).lapNumber <= lapCap);
const jsonl = kept.join("\n") + "\n";

// The exporter appends `position` after every field the round had before it,
// which is what leaves the rest of the line as it was -- and what lets the two
// fixtures differ in that one key and in nothing else.
const beforePosition =
  kept
    .map((line) => {
      const without = line.replace(/, "position": \d+ \}$/, " }");
      if (without === line) {
        throw new Error(`No position to strip, so the two fixtures would be one: ${line.slice(0, 80)}`);
      }
      return without;
    })
    .join("\n") + "\n";

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

// Decoding is per line, so one is the whole of what the extra field costs and
// the smallest thing that can be asked it.
const [firstLine] = kept;
const firstLineBeforePosition = firstLine.replace(/, "position": \d+ \}$/, " }");

const elm = `module Fixture.Positions exposing (lapCap, rawJsonl, rawJsonlBeforePosition, rawLap, rawLapBeforePosition, rawSummary)

{-| Auto-generated from ${from(summarySource)} and the first ${lapCap} laps of
${from(lapsSource)}. Do not edit by hand. Run
\`node generate-position-fixture.mjs\` to regenerate, \`--laps=N\` for a
different bound.
-}


{-| The lap the fixture stops at, which is what \`PositionBenchmark\` scales to.
-}
lapCap : Int
lapCap =
    ${lapCap}


rawSummary : String
rawSummary =
    """${summary}"""


rawJsonl : String
rawJsonl =
    """${jsonl}"""


{-| The same laps as the round was exported before it carried a position, which
is the one key the two differ by.
-}
rawJsonlBeforePosition : String
rawJsonlBeforePosition =
    """${beforePosition}"""


{-| One lap of the round, which is the unit decoding works in.
-}
rawLap : String
rawLap =
    """${firstLine}
"""


{-| The same lap without its position.
-}
rawLapBeforePosition : String
rawLapBeforePosition =
    """${firstLineBeforePosition}
"""
`;

mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, elm);
console.log(
  `Wrote ${target}: ${kept.length.toLocaleString()} of ${lines.length.toLocaleString()} laps ` +
    `(--laps=${lapCap}), ${(elm.length / 1e6).toFixed(1)}MB of Elm source`
);
