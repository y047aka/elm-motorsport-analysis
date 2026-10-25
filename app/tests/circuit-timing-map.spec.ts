import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync, realpathSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { authoredCircuits, readSource } from './helpers';

/**
 * The figures a circuit's timing lines are read at, held twice on purpose.
 * `circuits/src/Circuit.flix` authors them and the drawing is laid from them;
 * `Motorsport.Circuit.timingMap` holds the same ones for
 * `nix run .#geometry-timing-lines`, which reads no geometry file —
 * `Util.Json.Encode` writes and parses nothing. Neither compiler sees the other,
 * so a stretch moved in one copy and not the other leaves a report measuring one
 * lap while the drawing shows another, printing numbers that look like a circuit's
 * own.
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
 * The report's project shares `flix/src` by symlink, because Flix has no local
 * path dependency and `flix build` takes no source directory. Two facts hold that
 * sharing up, and neither is visible from either project's own build: a symlinked
 * directory is walked as nothing, so the links must be one per file; and a link
 * which does not survive a checkout fails as `Undefined use`, named in the module
 * that needed it rather than in the link that broke.
 *
 * A link compiles a whole module for the few of its functions one command calls,
 * so the links are held to the readings the report reads through. Where most of a
 * module belongs to the commands that compute in a database it is held separately:
 * `Cli/Errors.flix` states five of the CLI's eight cases and `Util/Files.flix`
 * three of its six functions, and the one case carrying a database's failure —
 * reached from no call here — was the whole reason `Db.flix` was a source of this
 * project at all.
 */

const reportRoot = fileURLToPath(new URL('../../circuits/timing/src', import.meta.url));

type Tree = { linked: string[]; held: string[] };

/** Every source under the report's `src`, sorted by whether it is a link. */
function walk(dir: string, found: Tree): Tree {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    const name = path.slice(reportRoot.length + 1);
    if (lstatSync(path).isSymbolicLink()) found.linked.push(name);
    else if (statSync(path).isDirectory()) walk(path, found);
    else if (entry.name.endsWith('.flix')) found.held.push(name);
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

/** The report's own command, and the two modules whose rest is the other
 * commands': an error type with no database in it, and a file reading that is
 * never given a file to write into. */
function heldSources(): string[] {
  return [
    'Cli/Errors.flix',
    'Cli/TimingLines.flix',
    'Cli/TimingLines/Feed.flix',
    'Main.flix',
    'Report.flix',
    'Util/Files.flix',
  ];
}

test('the report shares flix/src one file per symlink, and each one resolves', () => {
  const found = walk(reportRoot, { linked: [], held: [] });
  expect(found.linked.sort(), 'the report shares a different set of sources than the ones it reads').toEqual(
    sharedSources(),
  );
  expect(found.held.sort(), 'the report holds a source no test names').toEqual(heldSources());
  const root = realpathSync(fileURLToPath(new URL('../..', import.meta.url)));
  for (const name of sharedSources()) {
    const path = `${reportRoot}/${name}`;
    expect(lstatSync(path).isSymbolicLink(), `${name} is a copy of a shared source, so it can disagree with it`).toBe(
      true,
    );
    // A linked directory is walked as nothing, which is what makes the per-file
    // rule load-bearing rather than tidy.
    expect(statSync(path).isFile(), `${name} links a directory, which Flix will not descend`).toBe(true);
    expect(realpathSync(path), `${name} does not hold flix/src/${name}`).toBe(`${root}/flix/src/${name}`);
  }
});

/** Every source the report's compiler reads: its own, and what each link holds. */
function compiledSources(): string[] {
  return [...sharedSources(), ...heldSources()].map((name) => readSource(`circuits/timing/src/${name}`));
}

/**
 * A link to `flix/src/Db.flix` would compile — an effect declaration opens no
 * connection and needs no driver — so that the report has no way to name a
 * database is a fact about its sources and nothing else, and these are the
 * sources that say it.
 */
test('nothing the report compiles reaches a database', () => {
  const text = compiledSources().join('\n');
  for (const name of ['SqlRead', 'SqlWrite', 'DbErr', 'Db.Error', 'Db.Value', 'Jdbc']) {
    expect(text, `the report compiles ${name}, which no command here can reach`).not.toContain(name);
  }
  const files = readSource('circuits/timing/src/Util/Files.flix');
  expect(files, 'the report holds a Util.Files that writes, which is not the reading it is').not.toMatch(
    /pub def (write|mkDirs|walkCsvFiles)/,
  );
  expect(files, 'the report globs a directory').not.toContain('Glob');
});

test('the report resolves no dependency, which is the separation for', () => {
  const toml = readSource('circuits/timing/flix.toml');
  expect(toml, 'the report has a dependency, so a database is reachable from it').not.toMatch(/mvn-dependencies|dependencies/);
  // One compiler version for the two projects: a link out of `flix/src` is read by
  // whichever `flix` runs, and a source the other version parses differently fails
  // for a reason neither project states.
  const version = (file: string) => readSource(file).match(/flix\s*=\s*"([^"]+)"/)?.[1];
  expect(version('circuits/timing/flix.toml'), 'the two projects are not on one Flix version').toBe(version('flix/flix.toml'));
});
