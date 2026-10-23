// Whether a circuit's timing lines still stand where they were put a season
// earlier, read off the timing feed of two rounds at the same circuit.
//
//     node circuits/check-timing-lines.ts <season>/<id> [--against <season>]
//                                         [--tolerance <metres>]
//
// A circuit is drawn on one set of lines, and a new season at that circuit
// asks whether the lines have moved; this answers it without a map of the
// later year. The feed holds times, so the lines are inferred from them: each
// class's fastest sector, as a share of the fastest lap the same class could
// make, is read as a share of the distance round the lap. A sector's time is
// not proportional to the ground it covers — that ground is a mixture of
// corners and straights — and the fastest Hypercar laps put the first line
// some 170 m from where the circuit's own map draws it. So the shares are
// printed beside the map's lines and never judged against them, and what is
// judged against the tolerance is the season-to-season difference: both
// readings carry that error of the method, a line the organisers moved would
// show as hundreds of metres, and a changed Balance of Performance or a new
// tyre costs tens.
//
// The map's lines are read from the kept geometry, which publishes them as the
// circuit's script authored them. The reading of the feed is the summary's —
// the fastest sector over every lap, which is what `Round.Summary`'s
// `fastestSectors` asks the database — and where the round's export is in the
// tree its shares are printed against, so a stale export reads as a
// disagreement in the print rather than a verdict this command has no standing
// to make.
//
// This is the command; the reading itself — the CSV's text to rows, shares,
// lines and a season-to-season comparison — is `timing-feed.ts`, which opens
// nothing and is what `circuits/tests/timing-feed.test.ts` exercises.

import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";

import type { Circuit, GeometryFile, SectorLine } from "./circuit-geometry.ts";
import { reason, repoDir, sectorLines } from "./circuit-geometry.ts";
import { circuits } from "./registry.ts";
import type { Row, Round, Times } from "./timing-feed.ts";
import {
  fail,
  fastestSectors,
  impliedLines,
  lineMovement,
  metres,
  parseFeed,
  percent,
  readArgs,
  seconds,
  sectors,
  sharesOf,
  speeds,
  table,
  movedMetres,
  whole,
} from "./timing-feed.ts";

// The rounds this reads, each as the config of the circuit it is run on — a
// second round at a circuit already here is one more entry naming the same
// layout and lap.
const rounds: Record<string, Circuit> = {
  cota_6h: circuits.cota,
};

/** One season read: what each class was fastest at, and where round the lap
 * that implies the lines stand. */
type Reading = {
  season: number;
  id: string;
  path: string;
  laps: number;
  fastest: Map<string, Times>;
  lines: Map<string, number[]>;
};

// The table's columns: the class, each sector's fastest time and share, each
// intermediate line's implied position under the name the geometry gives it,
// and the mean speed the map's stretches work out to.
const columnsOf = (lines: SectorLine[]): [string, number][] => [
  ["class", 12],
  ...sectors.map((sector): [string, number] => [`${sector} s`, 9]),
  ...sectors.map((sector): [string, number] => [`${sector} %`, 8]),
  ...lines.map((line): [string, number] => [`${line.id} m`, 11]),
  ...sectors.map((sector): [string, number] => [`${sector} km/h`, 9]),
];

main().catch((error) => {
  console.error(reason(error));
  process.exit(1);
});

async function main(): Promise<void> {
  const args = readArgs(process.argv.slice(2));
  if (!Object.hasOwn(rounds, args.id)) {
    fail(`${args.id} is not a round this reads, which reads ${Object.keys(rounds).join(" and ")}.`);
  }
  const circuit = rounds[args.id];
  // The question this asks — do one map's lines still stand a season later —
  // has no answer on a circuit the organiser re-maps every year.
  if (circuit.sectors.kind !== "published") {
    fail(`${args.id} is run on ${circuit.survey}, whose timing map is not one set of lines: ${circuit.sectors.reason}.`);
  }

  const round: Round = { lapLength: circuit.lapLength, lines: await linesOf(circuit) };
  const seasons = args.against === null ? [args.season] : [args.season, args.against];

  const readings: { reading: Reading; note: string }[] = [];
  for (const season of seasons) {
    const reading = await readRound(season, args.id, round);
    readings.push({ reading, note: await agreesWithExport(reading) });
  }

  console.log(`The lines ${circuit.survey} is drawn on, out of ${circuit.script}: ${linePositions(round)}.`);
  for (const each of readings) printRound(each, round);
  if (args.against !== null) judge(readings[0].reading, readings[1].reading, round, circuit, args.tolerance);
}

// ---------------------------------------------------------------- the feed

/** One season of one round: how fast each class went round each sector, and where
 * round the lap that implies the lines stand. */
async function readRound(season: number, id: string, round: Round): Promise<Reading> {
  const path = join("data", "wec", String(season), `${id}.csv`);
  const laps = await readCsv(path);
  const fastest = fastestSectors(laps, path);
  return { season, id, path, laps: laps.length, fastest, lines: impliedLines(fastest, round) };
}

/** The feed's rows, one per lap. `path` is relative to the repository, as the
 * messages name it. */
async function readCsv(path: string): Promise<Row[]> {
  if (!existsSync(join(repoDir, path))) {
    fail(`there is no ${path} to read: the feed sits under data/wec/<season>/<id>.csv.`);
  }
  return parseFeed(await readFile(join(repoDir, path), "utf8"), path);
}

/** Whether this reading is the summary's reading — printed, never judged:
 * whether a pipeline reads its CSV the way it did when the export in the tree
 * was written is the pipeline's own business to test. */
async function agreesWithExport(reading: Reading): Promise<string> {
  const path = join("app", "static", "wec", String(reading.season), `${reading.id}.json`);
  if (!existsSync(join(repoDir, path))) {
    return `No export of ${reading.season}/${reading.id} in the tree to agree with.`;
  }

  const { track } = JSON.parse(await readFile(join(repoDir, path), "utf8"));
  const shares = sharesOf(reading.fastest.get(whole)!);
  const worst = Math.max(
    ...sectors.map((sector) => {
      const share = track?.sectors?.[sector.toLowerCase()]?.share;
      if (typeof share !== "number") {
        fail(`${path} names no '${sector.toLowerCase()}' share: there is nothing there to agree with.`);
      }
      return Math.abs(shares[sector] - share);
    }),
  );
  if (worst > 1e-9) {
    return `The export in the tree counts sectors ${worst.toExponential(1)} from this CSV -- it was written from a different one.`;
  }
  return "The export counts the same shares exactly.";
}

// ---------------------------------------------------------------- the layout

/** Where the map's lines stand round the lap, out of the geometry the circuit's
 * script wrote. The only thing a check may compare the map's own stretches
 * against is the lap length they add up to — the shares place a line some
 * 170 m from these, by the method's own error, and say nothing about a
 * mistake here. */
async function linesOf(round: Circuit): Promise<SectorLine[]> {
  const file = JSON.parse(await readFile(join(repoDir, round.geojson), "utf8")) as GeometryFile;
  const published = file.features?.find((f) => f.properties?.role === "outline")?.properties?.sectors;
  if (!published) {
    fail(`${round.geojson} publishes no sectors: ${round.script} authors them and a regeneration writes them.`);
  }
  if (published.stretches.length !== sectors.length) {
    fail(`${round.geojson} gives ${published.stretches.length} stretches for ${sectors.length} sectors.`);
  }
  return sectorLines(published, round.lapLength);
}

const linePositions = (round: Round) =>
  [...round.lines.map((line) => `${line.id} at ${metres(line.metres)} m`), `lap at ${metres(round.lapLength)} m`].join(", ");

// ---------------------------------------------------------------- printing

function printRound(each: { reading: Reading; note: string }, round: Round): void {
  const { season, id, path, laps } = each.reading;
  const columns = columnsOf(round.lines);
  console.log(`\n${season}/${id}: ${laps.toLocaleString("en-US")} laps of ${path}`);
  console.log(table(columns, columns.map(([name]) => name)));
  for (const [className, times] of each.reading.fastest) {
    const shares = sharesOf(times);
    const implied = each.reading.lines.get(className)!;
    console.log(
      table(columns, [
        className,
        ...sectors.map((sector) => seconds(times[sector]!)),
        ...sectors.map((sector) => percent(shares[sector])),
        ...implied.map((metre) => metres(metre)),
        ...speeds(times, round),
      ]),
    );
  }
  console.log(each.note);
}

function judge(season: Reading, against: Reading, round: Round, circuit: Circuit, limit: number): void {
  const shift = lineMovement(season.lines, against.lines);
  const columns: [string, number][] = [["class", 12], ...round.lines.map((line): [string, number] => [line.id, 11])];

  console.log(`\n${season.season} against ${against.season}: how far round the lap one line stands`);
  console.log(table(columns, columns.map(([name]) => name)));
  for (const className of shift.compared) {
    console.log(table(columns, [className, ...shift.moved.get(className)!.map(movedMetres)]));
  }
  for (const className of shift.oneSeasonOnly) {
    console.log(`${className} ran in one season only, so its lines are not compared.`);
  }

  if (shift.furthest > limit) {
    console.log(
      [
        `\n${metres(shift.furthest)} m is over the ${metres(limit)} m allowed:`,
        `${season.season} and ${against.season} are far enough apart at ${circuit.survey}`,
        `to read a map of the later one and place the lines by season, as Le Mans's are.`,
      ].join(" "),
    );
    process.exitCode = 1;
  } else {
    console.log(
      [
        `\nWithin the ${metres(limit)} m allowed -- ${percent(shift.furthest / round.lapLength)} of a lap:`,
        `one set of lines answers for ${against.season} and ${season.season}.`,
      ].join(" "),
    );
  }
}
