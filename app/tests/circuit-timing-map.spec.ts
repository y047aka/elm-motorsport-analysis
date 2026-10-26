import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync, realpathSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { authoredCircuits, readSource } from './helpers';

/**
 * The figures a circuit's timing lines are read at, held twice on purpose.
 * `circuits/src/Circuit.flix` authors them and the drawing is laid from them;
 * `Motorsport.Circuit.timingMap` holds the same ones for
 * `nix run .#geometry-timing-lines`, which reads no geometry file —
 * `Util.Json.Encode` writes and parses nothing. One project compiles both files,
 * and no compiler compares what they state: a stretch moved in one copy and not
 * the other leaves a report measuring one lap while the drawing shows another,
 * printing numbers that look like a circuit's own.
 *
 * The published numbers are read out of the Flix config and out of the geometry
 * the config was written into — the bytes the app is served — and the report's
 * out of its own source, the way `circuit-contract.spec.ts` reads both sides of
 * a circuit's name. Nothing here needs a browser.
 */

const circuits = authoredCircuits();

const flixSource = readSource('flix/src/Motorsport/Circuit.flix');

type Published = { lapLength: number; stretches: number[] };

/** What Flix states about one circuit's timing lines: one map and its
 * stretches, a reason its map is re-issued every season, or nothing surveyed. */
type FlixMap = { published?: Published; reissued?: string; unsurveyed: boolean };

/** The word jsonValue sends for each enum case `timingMap` is written over.
 * Flix closes the module's last definition with a `}` at column nought, which
 * is where the body ends. */
function caseNames(): Map<string, string> {
  const body = flixSource.split('pub def jsonValue')[1]?.split('\n}')[0] ?? '';
  const names = new Map(
    [...body.matchAll(/case Circuit\.([A-Za-z]+)\s*=>\s*"([a-z_]+)"/g)].map((m) => [m[1], m[2]]),
  );
  expect(names.size, 'Circuit.jsonValue sends no circuit name').toBeGreaterThan(0);
  return names;
}

/** The `case Circuit.<name> => TimingMap...` arms of `timingMap`, keyed by the
 * word a circuit is known by. */
function timingArms(): Map<string, string> {
  const names = caseNames();
  const body = flixSource.split('pub def timingMap')[1] ?? '';
  const arms = new Map<string, string>();
  const cases = /\n {12}case Circuit\.([A-Za-z]+)\s*=>([\s\S]*?)(?=\n {12}case Circuit\.|\n {8}})/g;
  for (const each of body.matchAll(cases)) {
    const word = names.get(each[1]);
    expect(word, `Circuit.timingMap has an arm for ${each[1]}, which jsonValue sends no name for`).toBeTruthy();
    arms.set(word!, each[2]);
  }
  expect(arms.size, 'Circuit.timingMap holds no arms to compare').toBeGreaterThan(0);
  return arms;
}

function flixMap(word: string): FlixMap {
  const arm = timingArms().get(word);
  expect(arm, `Circuit.timingMap says nothing about ${word}, which no circuit can be named by`).toBeTruthy();

  const published = arm!.match(/TimingMap\.Published\(\{\s*lapLength = ([0-9.]+),\s*stretches = List#\{([0-9., ]+)\}\s*\}\s*\)/);
  if (published) {
    return {
      published: {
        lapLength: Number(published[1]),
        stretches: published[2].split(',').map((each) => Number(each.trim())),
      },
      unsurveyed: false,
    };
  }

  const reissued = arm!.match(/TimingMap\.PerSeason\(\s*"([^"]+)"\s*\)/);
  if (reissued) return { reissued: reissued[1], unsurveyed: false };

  expect(arm!, `Circuit.timingMap's arm for ${word} names no map, no reason and no lack of survey`).toContain(
    'TimingMap.Unsurveyed',
  );
  return { unsurveyed: true };
}

/** The outline the pipeline wrote for a circuit, or nothing where no geometry
 * is kept for it -- which is what a circuit Flix calls unsurveyed looks like. */
function served(circuit: string): { sectors?: { stretches: number[] }; lapLength?: number } {
  let file;
  try {
    file = JSON.parse(readSource(`app/static/geometry/${circuit}.geojson`));
  } catch {
    return {};
  }
  const outline = file.features.find((f: { properties?: { role?: string } }) => f.properties?.role === 'outline');
  if (!outline) return {};
  return { sectors: outline.properties?.sectors, lapLength: outline.properties?.lap_length_m };
}

test('the report reads the lap the drawing was laid from', () => {
  for (const [word, circuit] of Object.entries(circuits)) {
    const held = flixMap(word);
    if (circuit.sectors.kind === 'published') {
      expect(held.published, `${word} authors one map and Circuit.timingMap holds none`).toBeTruthy();
      expect(held.published!.lapLength, `${word}: the report and the drawing are given different laps`).toBe(
        circuit.lap,
      );
      expect(held.published!.stretches, `${word}: the report and the drawing divide the lap differently`).toEqual(
        circuit.sectors.stretches,
      );
    } else {
      expect(held.published, `${word} publishes no one map, so the report holds no stretches for it`).toBeUndefined();
    }
  }
});

test('the geometry the app is served publishes the stretches the report reads', () => {
  const published = Object.entries(circuits).filter(([, circuit]) => circuit.sectors.kind === 'published');
  expect(published.length, 'no circuit here publishes one map of its timing lines').toBeGreaterThan(0);
  for (const [word, circuit] of published) {
    const held = flixMap(word).published!;
    const kept = served(circuit.word);
    expect(kept.sectors, `${word}: the kept geometry publishes no sectors to compare against`).toBeTruthy();
    expect(kept.lapLength, `${word}: the kept geometry is a different lap from the one the report reads`).toBe(
      held.lapLength,
    );
    expect(kept.sectors!.stretches, `${word}: the served geometry and the report divide the lap differently`).toEqual(
      held.stretches,
    );
  }
});

test('a circuit re-mapped every season is refused in both languages, quoting one reason', () => {
  const reissued = Object.entries(circuits).filter(([, circuit]) => circuit.sectors.kind === 'perSeason');
  expect(reissued.length, 'no circuit here is re-mapped every season').toBeGreaterThan(0);
  for (const [word, circuit] of reissued) {
    const held = flixMap(word);
    expect(held.reissued, `${word} is re-mapped every season and Circuit.timingMap gives no reason to refuse it`).toBe(
      circuit.sectors.reason,
    );
    // Nothing in the served file to read two seasons against, which is the whole
    // reason the report refuses the round rather than printing noughts.
    expect(served(circuit.word).sectors, `${word}: the geometry publishes sectors the config says differ by season`).toBeUndefined();
  }
});

test('every circuit Flix can name is answered for by timingMap', () => {
  const words = [...caseNames().values()];
  expect([...timingArms().keys()].sort(), 'Circuit.timingMap is not written over every circuit').toEqual(
    [...new Set(words)].sort(),
  );
});

test('a circuit Flix holds a map for is one whose config authors it that way', () => {
  for (const [word, circuit] of Object.entries(circuits)) {
    const arm = timingArms().get(word)!;
    if (circuit.sectors.kind === 'published') {
      expect(arm, `${word} publishes one map for every season`).toContain('TimingMap.Published');
    } else if (circuit.sectors.kind === 'perSeason') {
      expect(arm, `${word}'s map is re-issued every season`).toContain('TimingMap.PerSeason');
    } else {
      expect(arm, `${word} publishes no timing lines at all`).toContain('TimingMap.Unsurveyed');
    }
  }
  // A circuit nothing is surveyed for here has nothing to read a season against,
  // and says so rather than standing for a map that was never authored.
  for (const word of [...caseNames().values()].filter((each) => !(each in circuits))) {
    expect(flixMap(word).unsurveyed, `${word} has no config here, so the report has no lines to read for it`).toBe(true);
  }
});

/**
 * The one claim a circuit's published stretches are trusted with -- that they
 * add up to the lap -- is checked twice over, once per project, to a tenth of a
 * metre each: `Track.sectorLines` turns a geometry's `sectors` away and
 * `Feed.publishedLines` refuses the figures `Motorsport.Circuit` holds. Flix
 * has no local path dependency, so the tenth is spelled in both sources and
 * nothing compiles both; a tenth moved on one side alone would leave one
 * reader accepting stretches the other refuses.
 */
test('both readers trust the published stretches by the same tenth', () => {
  const tenth = (source: string, where: string): number => {
    const found = source.match(/Float64\.abs\([a-zA-Z]+ - [a-zA-Z]+\) > ([0-9.]+)/);
    expect(found, `${where} states no stretch-sum tolerance to compare`).toBeTruthy();
    return Number(found![1]);
  };
  const drawing = tenth(readSource('circuits/src/Track.flix'), 'Track.sectorLines');
  expect(drawing, 'the stretch-sum tolerance is not a readable distance').toBeGreaterThan(0);
  expect(
    tenth(readSource('circuits/src/Cli/TimingLines/Feed.flix'), 'Feed.publishedLines'),
    'one reader trusts stretches the other refuses',
  ).toBe(drawing);
});

/**
 * The report's readings come into the geometry project by symlink, because Flix
 * has no local path dependency and `flix build` takes no source directory. Two
 * facts hold that sharing up, and neither is visible from the project's own
 * build: a symlinked directory is walked as nothing, so the links must be one
 * per file; and a link which does not survive a checkout fails as `Undefined
 * use`, named in the module that needed it rather than in the link that broke.
 *
 * A link compiles a whole module for the few of its functions one command calls,
 * so the links are held to the readings the report reads through. Where most of a
 * module belongs to the commands that compute in a database it is held separately:
 * `Cli/Errors.flix` keeps four of the CLI's seven cases beside a fifth the CLI
 * holds no failure like, and `Report/Files.flix` reads and stats — the pipeline's
 * own `Util/Files.flix` resolves every path from `GEOMETRY_FROM` and writes, while
 * the report's reads where it stands and writes nothing.
 */

const projectRoot = fileURLToPath(new URL('../../circuits/src', import.meta.url));

/** Every symlink under `circuits/src`, named by its path in the project. */
function walk(dir: string, found: string[]): string[] {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    if (lstatSync(path).isSymbolicLink()) found.push(path.slice(projectRoot.length + 1));
    else if (statSync(path).isDirectory()) walk(path, found);
  }
  return found;
}

/** The shared readings, each named as the path under `flix/src` it holds. */
function sharedSources(): string[] {
  return [
    'Cli.flix',
    'Motorsport.flix',
    'Motorsport/Calendar.flix',
    'Motorsport/Circuit.flix',
    'Motorsport/Events.flix',
    'Util/Csv.flix',
    'Util/Csv/Decode.flix',
    'Util/Csv/Parser.flix',
    'Util/Duration.flix',
  ];
}

test('the project shares flix/src one file per symlink, and each one resolves', () => {
  expect(walk(projectRoot, []).sort(), 'the project shares a different set of sources than the report reads').toEqual(
    sharedSources(),
  );
  const root = realpathSync(fileURLToPath(new URL('../..', import.meta.url)));
  for (const name of sharedSources()) {
    const path = `${projectRoot}/${name}`;
    expect(lstatSync(path).isSymbolicLink(), `${name} is a copy of a shared source, so it can disagree with it`).toBe(
      true,
    );
    // A linked directory is walked as nothing, which is what makes the per-file
    // rule load-bearing rather than tidy.
    expect(statSync(path).isFile(), `${name} links a directory, which Flix will not descend`).toBe(true);
    expect(realpathSync(path), `${name} does not hold flix/src/${name}`).toBe(`${root}/flix/src/${name}`);
  }
});

/**
 * A link to `flix/src/Db.flix` would compile — an effect declaration opens no
 * connection and needs no driver — so that the report has no way to name a
 * database is a fact about the project's sources and its `flix.toml`, which
 * `circuits-geometry-project.spec.ts` reads over every source, each link
 * dereferenced. What is read here instead is narrower: the report's own file
 * reading is given nothing to write into.
 */
test('the report reads and stats a file, and never writes one', () => {
  const files = readSource('circuits/src/Report/Files.flix');
  expect(files, 'the report holds a file reading that writes').not.toMatch(
    /pub def (write|mkDirs|walkCsvFiles)/,
  );
  expect(files, 'the report globs a directory').not.toContain('Glob');
});
