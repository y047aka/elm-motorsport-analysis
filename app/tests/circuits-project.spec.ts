import { readdirSync } from 'node:fs';
import { relative } from 'node:path';
import { fileURLToPath } from 'node:url';

import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * What the geometry project cannot see from inside itself, read out of its sources.
 *
 * The project's own tests hand their fixtures: they reach no network, build no
 * `HttpResponse`, and ask nothing of the file system. So the project-wide facts —
 * one reading of what a service answered with, one spelling of the sphere its
 * metres are measured on, one way a filesystem failure is answered — are invisible
 * to both Flix compilers and are read here. A failure they hide is quiet: a second
 * reading of a response that asked only the status would hand a proxy's 200-with-
 * HTML-page on as a geometry; a second spelling of the radius on the equatorial
 * one prints 13,627 m for the lap the survey measures at 13,612, and the measured
 * lap is the one reading a config is authored from; a read's failure decided as
 * an absence exits 0.
 *
 * Nothing here needs a browser. The asking's shapes — each question recursing to
 * `way(r)`, and only the survey asking for `node(w)` — are pinned by the project's
 * own `flix test`, `circuits/src/Overpass.flix` having written the asking once.
 */

const root = fileURLToPath(new URL('../../', import.meta.url));
const sourcesDir = fileURLToPath(new URL('../../circuits/src', import.meta.url));

/** The geometry project's own sources, by the path a message names them by. The nine links
 * into `flix/src` are left out: they are the report's, and the report reaches no file of
 * the pipeline's and no HTTP at all — it reads the feeds through `Report.Files`. */
function projectSources(): string[] {
  return readdirSync(sourcesDir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.flix'))
    .map((entry) => relative(root, `${entry.parentPath ?? entry.path}/${entry.name}`))
    .sort();
}

function spelling(re: RegExp): string[] {
  return projectSources().filter((path) => re.test(readSource(path)));
}

/** The `def` a piece of source stands in, which is how far a match arm's meaning reaches:
 * an arm that throws a failure away means something different in every function. */
function enclosingDef(path: string, needle: string): string {
  const text = readSource(path);
  const at = text.indexOf(needle);
  if (at < 0) throw new Error(`${needle} is not in ${path}`);
  const defs = [...text.slice(0, at).matchAll(/^\s+(?:pub )?def (\w+)/gm)].map((found) => found[1]);
  return defs[defs.length - 1] ?? '';
}

const utilFiles = 'circuits/src/Util/Files.flix';
const cliErrors = 'circuits/src/Cli/Errors.flix';
const reportFiles = 'circuits/src/Report/Files.flix';
const regenerate = 'circuits/src/Regenerate.flix';
const overpass = 'circuits/src/Overpass.flix';
const atlas = 'circuits/src/Atlas.flix';

// ---------------------------------------------------------------- the sphere

test('the project spells its sphere once', () => {
  const sources = ['Apart.flix', 'Candidates.flix', 'Probe.flix', 'Survey.flix'];
  const stated = sources
    .map((source) => readSource(`circuits/src/${source}`))
    .flatMap((text) => text.match(/63\d{5}/g) ?? []);
  expect(stated.length, 'the earth radius is not spelled exactly once across the project').toBe(1);
  expect(
    stated[0],
    'the one spelling of the earth radius is not Apart.earthMetres',
  ).toBe(readSource('circuits/src/Apart.flix').match(/63\d{5}/)![0]);
});

// ------------------------------------------------------------ the response

test('one source reads what a service answered with', () => {
  const reading = spelling(/Net\.HttpResponse\./);
  expect(reading, `${reading.join(', ')} reads a response besides Overpass.flix`).toEqual([overpass]);
});

test('the services asked are the survey runners and the atlas home', () => {
  const asking = spelling(/Https\.send\(/);
  expect(asking).toEqual([atlas, overpass]);
});

test('the atlas reads its answer where the survey reads its own', () => {
  expect(readSource(atlas), 'the atlas reading answers with its own reading of a response').toMatch(
    /Overpass\.answered\(/,
  );
});

test('the sentence a failed answer is printed in is spelled once', () => {
  const failed = /answered( \$\{| with something that is not JSON)/;
  const spelled = spelling(failed);
  expect(spelled, `${spelled.join(', ')} spell a failed answer besides Overpass.flix`).toEqual([overpass]);
});

// -------------------------------------------------------------- the failure

test('no run answers a failure by throwing it away', () => {
  const discarded = projectSources().flatMap((path) =>
    readSource(path)
      .split('\n')
      .filter((line) => line.includes('Err(_)'))
      .map((line) => `${path}: ${line.trim()}`),
  );

  // One arm answers a failure by discarding it, and the failure it discards is a parse
  // another reading refused first: `claimed` reads an outline's properties out of the text
  // `Geometry.outline` was already asked to parse, so a file that will not parse claims
  // nothing for a reason `Geometry` said, in its own words.
  expect(discarded, `${discarded.join('\n')} throw a failure away`).toEqual([
    `circuits/src/Atlas.flix: case Err(_)   => Map.empty()`,
  ]);
  expect(enclosingDef(atlas, 'case Err(_)')).toBe('claimed');
});

test('a run asking whether a file is there asks the path it was given', () => {
  const files = readSource(utilFiles);
  expect(files).toMatch(/pub def exists\(path: String\): Result\[String, Bool\] \\ IO/);
  expect(files).toMatch(/pub def isDirectory\(dir: String\): Result\[String, Bool\] \\ IO/);

  // Resolved before the filesystem is asked, the way a read and a write resolve it: a run
  // from outside the project branches about the file it named, not about one under the
  // directory `flix` happened to start in.
  expect(files).toMatch(/let at = placed\(path\);\n\s*Fs\.FileStat\.runWithIO\(\(\) -> Fs\.FileStat\.exists\(at\)\)/);
  expect(files).toMatch(/let at = placed\(dir\);\n\s*Fs\.FileStat\.runWithIO\(\(\) -> Fs\.FileStat\.isDirectory\(at\)\)/);

  // A stat that answered nothing is a failure and not a `false`, because `false` is the
  // answer that ends a walk quietly.
  expect(files, 'a failed stat answers that there is nothing there').not.toMatch(/mapErr\([^)]*=>\s*Ok\(false\)/);
  expect(files).toMatch(/cannot tell whether \$\{path\}/);
});

test('the two readings of a file resolve a path differently, on purpose', () => {
  // The geometry commands read through `Cli.Errors`, which carries the path with the
  // failure; reaching past it to `Util.Files.read` leaves the failure naming nothing.
  expect(spelling(/Util\.Files\.read\(/), 'a command reads a file outside Cli.Errors').toEqual([cliErrors]);
  expect(spelling(/Util\.Files\.write\(/), 'a command writes a file outside Cli.Errors').toEqual([cliErrors]);

  // The report reads where the reader stands: the feeds' directory is what a reader typed,
  // and resolving it against `GEOMETRY_FROM` would look beside the project instead.
  expect(readSource(reportFiles), 'the report resolves a path it was not given').not.toContain('placed(');
  expect(readSource(reportFiles)).toMatch(/Fs\.FileStat\.exists\(path\)/);
});

test('a look the warning cannot make fails the run rather than passing it', () => {
  const fence = readSource(regenerate);
  expect(fence, 'the look the warning makes cannot fail').toMatch(/def warnUnlisted\(\): Result\[String, List\[String\]\] \\ IO/);

  const asking = fence.slice(fence.indexOf('def asking('), fence.indexOf('def warnUnlisted('));
  expect(asking, 'a warning this could not compute exits 0').toMatch(/case Err\(problem\) => Outcome\.Failed\(problem\)/);

  // A plain file among the directories is not a directory that keeps nothing, so the walk
  // asks which it is rather than listing it and reading the failure for an empty one.
  expect(fence).toMatch(/Util\.Files\.isDirectory\(at\)/);
});

test('the report reads and stats a file, and never writes one', () => {
  // The report's command computes in no database and lays down no file; a future edit
  // that gives its reading a `write` would compile and be invisible to every Flix test.
  const files = readSource(reportFiles);
  expect(files, 'the report holds a file reading that writes').not.toMatch(
    /pub def (write|mkDirs|walkCsvFiles)/,
  );
  expect(files, 'the report globs a directory').not.toContain('Glob');
});
