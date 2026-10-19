// Whether a circuit's timing lines still stand where they were put a season
// earlier, read off the timing feed of two rounds at the same circuit.
//
//     node scripts/check-timing-lines.mjs <season>/<id> [--against <season>]
//                                         [--tolerance <metres>]
//
// A circuit is drawn on one set of lines. Where they come from a document of one
// year -- the Circuit of the Americas' own track sector map, which is what
// `Circuit/Cota/Layout` is drawn on, and every season of it since -- a new season
// at that circuit asks whether the lines have moved. This answers it without a map
// of the later year.
//
// The feed holds times, so the lines are inferred from them: each class's fastest
// sector, as a share of the fastest lap the same class could make, is read as a
// share of the distance round the lap. How that is wrong is worth saying out loud.
// A sector's time is not proportional to the ground it covers, since the ground a
// sector covers is a mixture of corners and straights, and the shares of the
// fastest Hypercar laps put the first line some 170 m from where the circuit's own
// map draws it. What shares are good for is the difference between two seasons.
// Both readings carry that error of the method, so a class that drove over the same
// lines in two seasons implies lines that agree; a line the organisers moved would
// show as hundreds of metres, and a changed Balance of Performance or a new tyre
// costs tens.
//
// So the shares are printed beside the map's lines and never judged against them,
// and the season-to-season difference is the thing judged against the tolerance.
//
// The map's lines are read from the kept geometry, `app/static/geometry/<circuit>.geojson`, which
// publishes them as the circuit's script authored them. The reading of the feed
// is the summary's -- the fastest sector over every lap, which is what
// `Round.Summary`'s `fastestSectors` asks the database --
// and where the round's export is in the tree its shares are printed against, so
// a stale export reads as a disagreement in the print rather than as a verdict
// this command has no standing to make.

import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { circuit as cota } from "./cota-geometry.mjs";


const repoDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

// How far round the lap a line implied one season may sit from the same line
// implied the season after before the two are said to be on different lines. What
// set it is the two rounds of the Circuit of the Americas there are: their fastest
// sectors imply lines 28.3 m apart at the widest class, and a line the series
// actually moved would land hundreds of metres away.
const tolerance = 40.0;

const sectors = ["S1", "S2", "S3"];

// The class every lap of the field is pooled into, whose shares are the summary's.
const whole = "the round";

// The rounds this reads, and the lines each is drawn on. A circuit timed at one
// grain per season is not this question to ask: Le Mans's lines are copied from the
// organiser's map of each year and differ between them by design, so there is
// nothing to check there that a map does not already answer. A second round at a
// circuit already here is one more entry naming the same layout and lap.
const rounds = {
  cota_6h: {
    circuit: cota.survey,
    script: cota.script,
    geojson: cota.geojson,
    lapLength: cota.lapLength,
  },
};

const columns = [
  ["class", 12],
  ["S1 s", 9],
  ["S2 s", 9],
  ["S3 s", 9],
  ["S1 %", 8],
  ["S2 %", 8],
  ["S3 %", 8],
  ["line 1 m", 11],
  ["line 2 m", 11],
  ["S1 km/h", 9],
  ["S2 km/h", 9],
  ["S3 km/h", 9],
];

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});

async function main() {
  const args = readArgs(process.argv.slice(2));
  if (!Object.hasOwn(rounds, args.id)) {
    fail(`${args.id} is not a round this reads, which reads ${Object.keys(rounds).join(" and ")}.`);
  }

  const round = { ...rounds[args.id], lines: await linesOf(rounds[args.id]) };
  const seasons = args.against === null ? [args.season] : [args.season, args.against];

  const readings = [];
  for (const season of seasons) {
    const reading = await readRound(season, args.id, round);
    readings.push({ reading, note: await agreesWithExport(reading) });
  }

  console.log(`The lines ${round.circuit} is drawn on, out of ${round.script}: ${linePositions(round.lines)}.`);
  for (const each of readings) printRound(each, round, round.lines);
  if (args.against !== null) judge(readings[0].reading, readings[1].reading, round, args.tolerance);
}

// ---------------------------------------------------------------- the feed

/** One season of one round: how fast each class went round each sector, and where
 * round the lap that implies the lines stand. */
async function readRound(season, id, round) {
  const path = join("data", "wec", String(season), `${id}.csv`);
  const laps = await readCsv(path);
  const fastest = fastestSectors(laps, path);
  return { season, id, path, laps: laps.length, fastest, lines: impliedLines(fastest, round.lapLength) };
}

/** The feed's rows, one per lap. `path` is relative to the repository, as the
 * messages name it. */
async function readCsv(path) {
  if (!existsSync(join(repoDir, path))) {
    fail(`there is no ${path} to read: the feed sits under data/wec/<season>/<id>.csv.`);
  }
  const [header, ...rest] = (await readFile(join(repoDir, path), "utf8"))
    .replace(/^\uFEFF/, "")
    .trimEnd()
    .split(/\r?\n/);
  const keys = header.split(";").map((key) => key.trim());
  return rest.map((line, index) => {
    const cells = line.split(";").map((cell) => cell.trim());
    if (cells.length !== keys.length) {
      fail(`${path} line ${index + 2} has ${cells.length} fields, not ${keys.length}.`);
    }
    return Object.fromEntries(keys.map((key, at) => [key, cells[at]]));
  });
}

/** The fastest time through each sector of each class, and of the field whole --
 * the field's own being the fastest of the classes, which is what the summary's
 * shares are counted from. */
function fastestSectors(rows, path) {
  const best = new Map();
  for (const [index, lap] of rows.entries()) {
    const where = `${path} line ${index + 2}`;
    const className = lap["CLASS"];
    if (className === "") fail(`${where} names no class.`);
    if (!best.has(className)) best.set(className, noTimes());
    const times = best.get(className);
    for (const sector of sectors) {
      const time = msOf(lap[sector], where);
      if (time !== null && (times[sector] === null || time < times[sector])) times[sector] = time;
    }
  }

  for (const [className, times] of best) {
    if (sectors.some((sector) => times[sector] === null)) {
      fail(`${className} recorded no time in every sector.`);
    }
  }

  const field = noTimes();
  for (const sector of sectors) {
    field[sector] = Math.min(...[...best.values()].map((times) => times[sector]));
  }
  best.set(whole, field);
  return best;
}

const noTimes = () => Object.fromEntries(sectors.map((sector) => [sector, null]));

/** A sector time in milliseconds. Neither a blank nor a nought is a time: the feed
 * writes the lap it never recorded as `0.000`, and the sectors of such a lap are
 * not sectors of the circuit, so either would be the fastest of the round. */
function msOf(text, where) {
  if (text === "") return null;
  const parts = text.split(":");
  if (parts.length > 3 || parts.some((part) => !/^\d+(\.\d+)?$/.test(part))) {
    fail(`${where} cannot read "${text}" as a time.`);
  }
  const ms = Math.round(parts.reduce((total, part) => total * 60 + Number(part), 0) * 1000);
  return ms > 0 ? ms : null;
}

/** Each sector as a share of the fastest lap the same class could make. */
function sharesOf(times) {
  const total = sectors.reduce((sum, sector) => sum + times[sector], 0);
  return Object.fromEntries(sectors.map((sector) => [sector, times[sector] / total]));
}

/** Where round the lap those shares put the two intermediate lines. The third line
 * is the one the lap is measured from, which stands at nought and at the end. */
function impliedLines(fastest, lapLength) {
  const lines = new Map();
  for (const [className, times] of fastest) {
    const shares = sharesOf(times);
    lines.set(className, {
      first: shares.S1 * lapLength,
      second: (shares.S1 + shares.S2) * lapLength,
    });
  }
  return lines;
}

/** Whether this reading is the summary's reading -- printed, never judged. An
 * export in the tree is a file a run wrote some time ago, and whether a pipeline
 * reads its CSV the way it did when the file was written is the pipeline's own
 * business to test. */
async function agreesWithExport(reading) {
  const path = join("app", "static", "wec", String(reading.season), `${reading.id}.json`);
  if (!existsSync(join(repoDir, path))) {
    return `No export of ${reading.season}/${reading.id} in the tree to agree with.`;
  }

  const { track } = JSON.parse(await readFile(join(repoDir, path), "utf8"));
  const shares = sharesOf(reading.fastest.get(whole));
  const worst = Math.max(
    ...sectors.map((sector) => Math.abs(shares[sector] - track.sectors[sector.toLowerCase()].share)),
  );
  if (worst > 1e-9) {
    return `The export in the tree counts sectors ${worst.toExponential(1)} from this CSV -- it was written from a different one.`;
  }
  return "The export counts the same shares exactly.";
}

// ---------------------------------------------------------------- the layout

/** Where the map's lines stand round the lap: the first line, the second, and
 * the lap the third ends at. The stretches are the map's own, kept in the
 * geometry by the script that authored them, and the only thing a check may
 * compare them against is the lap length they add up to --
 * the shares themselves place a line some 170 m from one of these, by the
 * method's own error, and say nothing about a mistake here. */
async function linesOf(round) {
  const outline = JSON.parse(await readFile(join(repoDir, round.geojson), "utf8")).features.find((f) => f.properties?.role === "outline");
  const published = outline?.properties?.sectors;
  if (!published) {
    fail(`${round.geojson} publishes no sectors: ${round.script} authors them and a regeneration writes them.`);
  }
  if (published.stretches.length !== sectors.length) {
    fail(`${round.geojson} gives ${published.stretches.length} stretches for ${sectors.length} sectors.`);
  }
  const total = published.stretches.reduce((sum, stretch) => sum + stretch, 0);
  if (Math.abs(total - round.lapLength) > 0.05) {
    fail(`${round.geojson}'s stretches add up to ${total} m, not its ${round.lapLength} m lap.`);
  }
  const first = published.stretches[0];
  return { first, second: first + published.stretches[1], lap: round.lapLength };
}

const linePositions = ({ first, second, lap }) =>
  [first, second, lap].map((metre, at) => `${sectors[at]} at ${metres(metre)} m`).join(", ");

// ---------------------------------------------------------------- printing

function printRound({ reading, note }, round, lines) {
  const { season, id, path, laps } = reading;
  console.log(`\n${season}/${id}: ${laps.toLocaleString("en-US")} laps of ${path}`);
  console.log(table(columns.map(([name]) => name)));
  for (const [className, times] of reading.fastest) {
    const shares = sharesOf(times);
    const implied = reading.lines.get(className);
    console.log(
      table([
        className,
        ...sectors.map((sector) => seconds(times[sector])),
        ...sectors.map((sector) => percent(shares[sector])),
        metres(implied.first),
        metres(implied.second),
        ...speeds(times, lines),
      ]),
    );
  }
  console.log(note);
}

/** The mean speed over each of the map's three stretches, which is what a sector
 * time taken for a share of the distance hides. */
function speeds(times, lines) {
  const stretches = [lines.first, lines.second - lines.first, lines.lap - lines.second];
  return sectors.map((sector, at) => ((stretches[at] / (times[sector] / 1000)) * 3.6).toFixed(1));
}

function judge(season, against, round, limit) {
  const both = [...season.lines.keys()].filter((className) => against.lines.has(className));
  const moved = (className, which) => season.lines.get(className)[which] - against.lines.get(className)[which];
  const apart = (className) => ["first", "second"].map((which) => Math.abs(moved(className, which)));

  console.log(`\n${season.season} against ${against.season}: how far round the lap one line stands`);
  console.log(table(["class", "line 1", "line 2"]));
  for (const className of both) {
    const by = ["first", "second"].map((which) => movedMetres(moved(className, which)));
    console.log(table([className, ...by]));
  }
  for (const className of new Set([...season.lines.keys(), ...against.lines.keys()])) {
    if (!both.includes(className) && className !== whole) {
      console.log(`${className} ran in one season only, so its lines are not compared.`);
    }
  }

  const furthest = Math.max(...both.flatMap(apart));
  if (furthest > limit) {
    console.log(
      [
        `\n${metres(furthest)} m is over the ${metres(limit)} m allowed:`,
        `${season.season} and ${against.season} are far enough apart at ${round.circuit}`,
        `to read a map of the later one and place the lines by season, as Le Mans's are.`,
      ].join(" "),
    );
    process.exitCode = 1;
  } else {
    console.log(
      [
        `\nWithin the ${metres(limit)} m allowed -- ${percent(furthest / round.lapLength)} of a lap:`,
        `one set of lines answers for ${against.season} and ${season.season}.`,
      ].join(" "),
    );
  }
}

const table = (cells) =>
  cells.map((cell, at) => String(cell).padEnd(columns[at] ? columns[at][1] : String(cell).length)).join(" ");

const seconds = (ms) => (ms / 1000).toFixed(3);
const percent = (share) => `${(share * 100).toFixed(2)}%`;
const metres = (value) => value.toLocaleString("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const movedMetres = (value) => `${value < 0 ? "-" : "+"}${metres(Math.abs(value))} m`;

function fail(message) {
  throw new Error(message);
}

// ---------------------------------------------------------------- arguments

function readArgs(argv) {
  const args = { season: null, id: null, against: null, tolerance };
  for (let at = 0; at < argv.length; at++) {
    if (argv[at] === "--against") args.against = argv[++at];
    else if (argv[at] === "--tolerance") args.tolerance = Number(argv[++at]);
    else if (args.id === null) {
      const round = String(argv[at]).match(/^(\d{4})\/([\w-]+)$/);
      if (round === null) fail(`"${argv[at]}" is not a <season>/<id> like 2026/cota_6h.`);
      [, args.season, args.id] = round;
    } else fail(`unknown argument: ${argv[at]}`);
  }
  if (args.id === null) {
    fail("usage: node scripts/check-timing-lines.mjs <season>/<id> [--against <season>] [--tolerance <metres>]");
  }
  if (args.against !== null && !/^\d{4}$/.test(String(args.against))) fail(`"${args.against}" is not a season.`);
  if (!Number.isFinite(args.tolerance) || args.tolerance <= 0) fail(`"${args.tolerance}" is not a distance.`);
  args.season = Number(args.season);
  args.against = args.against === null ? null : Number(args.against);
  return args;
}
