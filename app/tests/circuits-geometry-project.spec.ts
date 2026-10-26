import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync } from 'node:fs';

import { readSource } from './helpers';

/**
 * The geometry project's own wiring, read from outside it.
 *
 * The pipeline is a Flix project at `circuits/` — asking OpenStreetMap,
 * surveying an answer into a lap, writing the bytes the app serves, comparing
 * two kept geometries, reading a track-atlas line, and fencing a regeneration
 * — and every reading in it is held by the project's own `flix test`. What a
 * Flix test cannot see is the wiring around the project: which sources the
 * project holds, what it resolves, the flake apps that reach it, the directory
 * a reader's paths resolve against, and the CI steps that compare rather than
 * write. Those are read here, the way `circuit-overpass.spec.ts` reads the
 * probe's and `circuit-timing-map.spec.ts` the report's.
 *
 * Nothing here needs a browser.
 */

const command = readSource('circuits/src/Diff.flix');
const atlasReading = readSource('circuits/src/Atlas.flix');
const main = readSource('circuits/src/Main.flix');

/**
 * Every `.flix` file on one shelf of the geometry project, with a symlink named rather than
 * followed. The timing report links nine of `flix/src`'s sources because it reads readings
 * that live there; this project reads none of them, and a link would compile — `Sql.flix`
 * declares an effect that opens no connection — so a project could acquire a way to name a
 * database without being asked to.
 */
function readDir(dir: string): string[] {
  const found: string[] = [];
  const walk = (at: string) => {
    for (const entry of readdirSync(new URL(`../../${at}`, import.meta.url), { withFileTypes: true })) {
      const path = `${at}/${entry.name}`;
      if (lstatSync(new URL(`../../${path}`, import.meta.url)).isSymbolicLink()) {
        throw new Error(`${path} links out of the geometry project, which shares no source with anything`);
      }
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('.flix')) found.push(path);
    }
  };
  walk(dir);
  return found.sort();
}

const project = [...readDir('circuits/src'), ...readDir('circuits/test')];

/**
 * Every source the geometry project compiles — fourteen of Flix and nine of tests, which is
 * what the project is asserted to hold — for the reading of their text alone: a word a
 * database is named by would arrive in a source file and not in a build product.
 */
const everySource = project.map(readSource);

/**
 * One plane, taken about the mean latitude of the places of *both* lines: neither line is
 * drawn at a scale of its own, which is the only reason a survey stretched to a published
 * lap length and a line measured at its own are compared place against place. Where the two
 * callers project the lines together is what no fixture says: the diff hands over every
 * place of the lines it lays, and the atlas reading throws its pit lane and its markers
 * into the mean beside them.
 */
test('both lines are laid on one plane about the places of both', () => {
  expect(
    command.match(/Apart\.parallelOf\(List\.flatMap\(line -> line#coords, lines\)\)/),
    'the diff no longer projects the two lines together',
  ).toBeTruthy();
  expect(
    atlasReading.match(/Apart\.parallelOf\(coords \+\+ ours#coords \+\+ ours#pit \+\+ markers\)/),
    'the atlas reading no longer projects the lines, the pit lane and the markers together',
  ).toBeTruthy();
});

/**
 * The geometry project, read the way `circuit-overpass.spec.ts` reads the probe's:
 * a flake app whose entry point has moved fails at whoever typed it, in a shell,
 * with nothing to say why. The flake registers one app and hands it the whole
 * command line, so the subcommand words live only in `Main.flix` — a renamed
 * subcommand is a word Main answers with the usage there and no second place
 * to move. The test therefore pins the one app's forwarding and that Main's
 * list of words and Main's dispatch of them are the same list.
 */
test("the flake's geometry command reaches the source it runs", () => {
  const flake = readSource('flake.nix');
  const registered = [...flake.matchAll(/mkGeometryApp "([\w-]+)"/g)].map((m) => m[1]);
  expect(registered.sort(), 'the flake registers a different set of geometry commands than these').toEqual([
    'geometry',
  ]);
  expect(
    flake,
    'nix run .#geometry no longer hands the jar the reader\'s whole command line',
  ).toContain('mkGeometryApp "geometry" "flix run -- \\"$@\\""');
  expect(main, 'nix run .#geometry -- diff runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Diff.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry -- survey runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Write.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry -- fetch runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Fetch.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry -- write runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Write.writeExitCode(rest))',
  );
  expect(main, 'nix run .#geometry -- regenerate runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Regenerate.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry -- atlas runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Atlas.exitCode(rest))',
  );
  expect(main, 'the commands Main names and the commands it dispatches are not the same').toContain(
    '"atlas" :: "diff" :: "fetch" :: "regenerate" :: "survey" :: "write" :: Nil',
  );
  // `geometry-test` is the one way every project under `circuits/` is tested in
  // CI, and `flix` has to start inside each project to find its `flix.toml`.
  for (const dir of ['circuits', 'circuits/timing', 'circuits/probe']) {
    expect(flake, `geometry-test no longer runs flix test inside ${dir}`).toContain(`(cd ${dir} && flix test)`);
  }
});

/**
 * The geometry project is a Flix project of `circuits/` that shares no source with the
 * CLI and reads no database: `flix/src` is reached by the timing report through symlinks
 * because the report reads readings that live there, and this project reads none — every
 * figure in it is a distance between two places in a file.
 *
 * A link into `flix/src` would compile, which is what makes this worth a test:
 * `Sql.flix` declares an effect that opens no connection, so a project that symlinked it
 * acquires a way to name a database that no command in it can reach, and `flix/flix.toml`
 * resolves a JDBC driver for it.
 */
test('the geometry project shares no source, resolves no dependency and names no database', () => {
  expect(project, 'the geometry project holds a different set of sources than these').toEqual([
    'circuits/src/Apart.flix',
    'circuits/src/Atlas.flix',
    'circuits/src/Circuit.flix',
    'circuits/src/Diff.flix',
    'circuits/src/Fetch.flix',
    'circuits/src/Geometry.flix',
    'circuits/src/Main.flix',
    'circuits/src/Overpass.flix',
    'circuits/src/Regenerate.flix',
    'circuits/src/Survey.flix',
    'circuits/src/Track.flix',
    'circuits/src/Util/Files.flix',
    'circuits/src/Util/Format.flix',
    'circuits/src/Write.flix',
    'circuits/test/TestApart.flix',
    'circuits/test/TestDiff.flix',
    'circuits/test/TestFetch.flix',
    'circuits/test/TestGeometry.flix',
    'circuits/test/TestOverpass.flix',
    'circuits/test/TestRegenerate.flix',
    'circuits/test/TestSurvey.flix',
    'circuits/test/TestTrack.flix',
    'circuits/test/TestWrite.flix',
  ]);

  const toml = readSource('circuits/flix.toml');
  expect(toml, 'the geometry project resolves a dependency, so a database is reachable from it').not.toMatch(
    /mvn-dependencies|\[dependencies\]/,
  );
  for (const name of ['SqlRead', 'SqlWrite', 'DbErr', 'Db.Error', 'Jdbc', 'sqlite']) {
    expect(everySource.join('\n'), `the geometry project names ${name}`).not.toContain(name);
  }

  // One compiler version for the projects under circuits/ and the CLI: a source is read
  // by whichever `flix` runs, and a version the others moved past fails for a reason no
  // project states.
  const version = (path: string) => readSource(path).match(/flix\s*=\s*"([^"]+)"/)?.[1];
  expect(version('circuits/flix.toml'), 'the geometry project is not on the CLI\'s Flix version').toBe(
    version('flix/flix.toml'),
  );
  expect(version('circuits/probe/flix.toml'), 'the two newer Flix projects are not on one Flix version').toBe(
    version('flix/flix.toml'),
  );
});

/**
 * The reading of a kept file reaches a path where the reader was standing rather than
 * where `flix` was started, because the flake's runner has to change directory to find
 * `flix.toml`. The variable that carries it is named in the flake and read here: rename
 * one and not the other, and every relative path a reader types is a file not found —
 * with the name of the file they typed in the message, which points nowhere.
 */
test('a path a reader types is read from where they typed it', () => {
  expect(readSource('flake.nix'), 'the flake no longer hands the geometry project the directory it was run from').toContain(
    'export GEOMETRY_FROM="$PWD"',
  );
  const reader = readSource('circuits/src/Util/Files.flix');
  expect(reader, 'the geometry project no longer asks for the directory it was run from').toContain(
    'Env.getVar("GEOMETRY_FROM")',
  );
});

/**
 * The byte fence runs in CI over both surveyed circuits, comparing and never
 * writing: a `--write` in CI would make the fence pass by rewriting what it is
 * meant to be fencing.
 */
test('the Flix survey is fenced against the bytes the app serves', () => {
  const workflow = readSource('.github/workflows/test.yml');
  for (const circuit of ['cota', 'le_mans']) {
    expect(
      workflow,
      `CI no longer asks whether the Flix survey lays ${circuit}'s kept geometry`,
    ).toContain(`nix run .#geometry -- survey ${circuit}`);
  }
  expect(workflow, 'CI no longer runs the geometry project').toContain('nix run .#geometry-test geometry');
  for (const step of workflow.match(/nix run \.#geometry -- survey[^\n]*/g) ?? []) {
    expect(step, `CI writes ${step.trim()} rather than comparing it`).not.toContain('--write');
  }
});
