import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync, realpathSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { readSource } from './helpers';

/**
 * The nine readings the timing report shares with `flix/src`, held as links.
 *
 * The report's own figures — the published lap length and sector stretches —
 * were once compared to the geometry project's config here, by reading both
 * sources as text. `circuits/test/TestTimingMap.flix` lays those two copies
 * together now, compiled in the project that compiles both, which is the
 * stronger reading; nothing in that comparison needs a file system.
 *
 * What does is this: the report's readings come into the geometry project by
 * symlink, because Flix has no local path dependency and `flix build` takes no
 * source directory. Two facts hold that sharing up, and neither is visible from
 * the project's own build: a symlinked directory is walked as nothing, so the
 * links must be one per file; and a link which does not survive a checkout
 * fails as `Undefined use`, named in the module that needed it rather than in
 * the link that broke.
 *
 * A link compiles a whole module for the few of its functions one command
 * calls, so the links are held to the readings the report reads through. Where
 * most of a module belongs to the commands that compute in a database it is
 * held separately: `Cli/Errors.flix` keeps four of the CLI's seven cases beside
 * a fifth the CLI holds no failure like, and `Report/Files.flix` reads and
 * stats — the pipeline's own `Util/Files.flix` resolves every path from
 * `GEOMETRY_FROM` and writes, while the report's reads where it stands and
 * writes nothing.
 *
 * Nothing here needs a browser.
 */

/**
 * The shared readings, each named as the path under `flix/src` it holds.
 */
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
