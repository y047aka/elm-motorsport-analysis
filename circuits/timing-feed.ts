// The timing feed read without opening it: the rows a CSV's text leaves into,
// each class's fastest sector times, the shares those times become, the lines
// those shares place round the lap, and the season-to-season comparison of
// those lines. Nothing here reaches a file or the network; `check-timing-lines.ts`
// is the command that feeds this the text and prints its answers, which is why
// the readings can be tested without a round.
//
// The method's error — a sector's time is not a share of its distance — lives
// in `impliedLines` and is described in `check-timing-lines.ts`'s header and
// `circuits/README.md`; what lives here is only the arithmetic that error was
// measured against.

import type { Circuit, SectorLine } from "./circuit-geometry.ts";

/** A feed row: every column as the file wrote it. */
export type Row = Record<string, string>;

/** One class's fastest time through each sector, in milliseconds; null until a
 * time is recorded. */
export type Times = { [sector: string]: number | null };

/** A round as these readings need it: a circuit's config and the map's lines
 * the readings are printed against. */
export type Round = Circuit & { lines: SectorLine[] };

/** Parsed arguments: the round to read, the season to read it against, and how
 * far apart one line may come to stand in the two readings. */
export type Args = { season: number; id: string; against: number | null; tolerance: number };

export const sectors = ["S1", "S2", "S3"];

// The class every lap of the field is pooled into, whose shares are the summary's.
export const whole = "the round";

// How far round the lap a line implied one season may sit from the same line
// implied the season after before the two are said to be on different lines. What
// set it is the two rounds of the Circuit of the Americas there are: their fastest
// sectors imply lines 28.3 m apart at the widest class, and a line the series
// actually moved would land hundreds of metres away.
const tolerance = 40.0;

/** A reading that cannot go on, stated for the human the command prints it to. */
export function fail(message: string): never {
  throw new Error(message);
}

/** The feed's rows, one per lap, from the file's text. `path` names the file in
 * the messages and is never opened: a row whose cell count disagrees with the
 * header's is a corrupt feed, not a row to guess at. */
export function parseFeed(text: string, path: string): Row[] {
  const [header, ...rest] = text
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
export function fastestSectors(rows: Row[], path: string): Map<string, Times> {
  const best = new Map<string, Times>();
  for (const [index, lap] of rows.entries()) {
    const where = `${path} line ${index + 2}`;
    const className = lap["CLASS"];
    if (className === "") fail(`${where} names no class.`);
    if (!best.has(className)) best.set(className, noTimes());
    const times = best.get(className)!;
    for (const sector of sectors) {
      const time = msOf(lap[sector], where);
      const stood = times[sector];
      if (time !== null && (stood === null || time < stood)) times[sector] = time;
    }
  }

  for (const [className, times] of best) {
    if (sectors.some((sector) => times[sector] === null)) {
      fail(`${className} recorded no time in every sector.`);
    }
  }

  const field = noTimes();
  for (const sector of sectors) {
    field[sector] = Math.min(...[...best.values()].map((times) => times[sector]!));
  }
  best.set(whole, field);
  return best;
}

export const noTimes = (): Times => Object.fromEntries(sectors.map((sector) => [sector, null]));

/** A sector time in milliseconds. Neither a blank nor a nought is a time: the feed
 * writes the lap it never recorded as `0.000`, and the sectors of such a lap are
 * not sectors of the circuit, so either would be the fastest of the round. */
export function msOf(text: string, where: string): number | null {
  if (text === "") return null;
  const parts = text.split(":");
  if (parts.length > 3 || parts.some((part) => !/^\d+(\.\d+)?$/.test(part))) {
    fail(`${where} cannot read "${text}" as a time.`);
  }
  const ms = Math.round(parts.reduce((total, part) => total * 60 + Number(part), 0) * 1000);
  return ms > 0 ? ms : null;
}

/** Each sector as a share of the fastest lap the same class could make. */
export function sharesOf(times: Times): Record<string, number> {
  const total = sectors.reduce((sum, sector) => sum + times[sector]!, 0);
  return Object.fromEntries(sectors.map((sector) => [sector, times[sector]! / total]));
}

/** Where round the lap those shares put the intermediate lines, in the order
 * and under the names the geometry gives them. The line the lap is measured
 * from is not among them: it stands at nought and at the end. */
export function impliedLines(fastest: Map<string, Times>, round: Round): Map<string, number[]> {
  const lines = new Map<string, number[]>();
  for (const [className, times] of fastest) {
    const shares = sharesOf(times);
    let at = 0;
    const cum = sectors.map((sector) => (at += shares[sector]) * round.lapLength);
    lines.set(className, round.lines.map((_line, index) => cum[index]));
  }
  return lines;
}

/** The mean speed over each of the map's stretches, which is what a sector
 * time taken for a share of the distance hides. */
export function speeds(times: Times, round: Round): string[] {
  const edges = [0, ...round.lines.map((line) => line.metres), round.lapLength];
  return sectors.map((sector, at) => (((edges[at + 1] - edges[at]) / (times[sector]! / 1000)) * 3.6).toFixed(1));
}

/** How one season's implied lines stand against another's: each class in both
 * readings moved by the same line, and `furthest` the widest of those moves —
 * the figure the command judges against the tolerance. A class that ran in one
 * season only has no line to lay against the other's, and is named apart. */
export function lineMovement(
  season: Map<string, number[]>,
  against: Map<string, number[]>,
): { compared: string[]; moved: Map<string, number[]>; oneSeasonOnly: string[]; furthest: number } {
  const compared = [...season.keys()].filter((className) => against.has(className));
  const moved = new Map(
    compared.map((className) => [
      className,
      season.get(className)!.map((metre, at) => metre - against.get(className)![at]),
    ]),
  );
  const all = new Set([...season.keys(), ...against.keys()]);
  const oneSeasonOnly = [...all].filter((className) => !compared.includes(className));
  const distances = compared.flatMap((className) => moved.get(className)!.map(Math.abs));
  const furthest = distances.length === 0 ? 0 : Math.max(...distances);
  return { compared, moved, oneSeasonOnly, furthest };
}

// ---------------------------------------------------------------- formatting

export const table = (columns: [string, number][], cells: (string | number)[]) =>
  cells.map((cell, at) => String(cell).padEnd(columns[at] ? columns[at][1] : String(cell).length)).join(" ");

export const seconds = (ms: number) => (ms / 1000).toFixed(3);
export const percent = (share: number) => `${(share * 100).toFixed(2)}%`;
export const metres = (value: number) =>
  value.toLocaleString("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
export const movedMetres = (value: number) => `${value < 0 ? "-" : "+"}${metres(Math.abs(value))} m`;

// ---------------------------------------------------------------- arguments

export function readArgs(argv: string[]): Args {
  let season: string | null = null;
  let id: string | null = null;
  let against: string | null = null;
  let limit = tolerance;
  for (let at = 0; at < argv.length; at++) {
    if (argv[at] === "--against") against = argv[++at];
    else if (argv[at] === "--tolerance") limit = Number(argv[++at]);
    else if (id === null) {
      const round = String(argv[at]).match(/^(\d{4})\/([\w-]+)$/);
      if (round === null) fail(`"${argv[at]}" is not a <season>/<id> like 2026/cota_6h.`);
      season = round[1];
      id = round[2];
    } else fail(`unknown argument: ${argv[at]}`);
  }
  if (id === null || season === null) {
    fail("usage: node circuits/check-timing-lines.ts <season>/<id> [--against <season>] [--tolerance <metres>]");
  }
  if (against !== null && !/^\d{4}$/.test(against)) fail(`"${against}" is not a season.`);
  if (!Number.isFinite(limit) || limit <= 0) fail(`"${limit}" is not a distance.`);
  return { season: Number(season), id, against: against === null ? null : Number(against), tolerance: limit };
}
