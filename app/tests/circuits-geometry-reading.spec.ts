import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync } from 'node:fs';

import { readSource } from './helpers';

/**
 * One comparison, read in two languages, and no compiler sees both.
 *
 * The atlas command measures a measured line against a kept geometry in TypeScript
 * (`circuits/apartness.ts`, which `circuits/atlas-geometry.ts` imports), and the diff
 * lays the same two kinds of file against each other in Flix (`circuits/geometry/`,
 * `nix run .#geometry-diff`). They are deliberately separate programs — one writes an
 * atlas line into the repository, the other compares what is already there — but the
 * comparison they are built on is one set of arithmetic, and it is now written twice.
 *
 * A comparison that parts silently says nothing: the apartness of two lines sampled on
 * a different bound is a mean within a few metres of the truth, which reads as a real
 * reading of two lines that in fact disagree. The numbers a report prints are the same
 * hazard the other way round — a metre printed as `5515.0` where the kept files print
 * `5515` is a changed file, and a fence that compares bytes fails on the print alone. So
 * the bound of each loop, which stretch a tie falls on, how a zero-length stretch is
 * walked through, and the sphere both are laid on are read out of both sources here, the
 * way `circuit-overpass.spec.ts` reads the Overpass facts out of both sides of the
 * Flix/TypeScript line.
 *
 * Nothing here needs a browser.
 */

const node = readSource('circuits/apartness.ts');
const asking = readSource('circuits/geometry-diff.ts');
const kept = readSource('circuits/geometry-file.ts');
const flix = readSource('circuits/geometry/src/Apart.flix');
const file = readSource('circuits/geometry/src/Geometry.flix');
const command = readSource('circuits/geometry/src/Diff.flix');
const printed = readSource('circuits/geometry/src/Util/Format.flix');
const survey = readSource('circuits/circuit-geometry.ts');
const atlas = readSource('circuits/atlas-geometry.ts');

/**
 * Every source either reading compiles, for the reading of their text alone: the
 * project's own six and the two TypeScript modules it duplicates, since a word a database
 * is named by would arrive in a source file and not in a build product.
 */
const everySource = [
  node,
  kept,
  flix,
  file,
  command,
  printed,
  readSource('circuits/geometry/src/Util/Files.flix'),
  readSource('circuits/geometry/src/Main.flix'),
];

/**
 * The sampling stops short of the line's own end: a line of 100 m at 25 m is four
 * samples and not five, which is what `count` in the report means and what every kept
 * figure in the tests is a count of.
 */
test("both languages stop sampling at the line's own end", () => {
  expect(node.match(/for \(let s = 0; s < length; s \+= every\)/), 'the TypeScript sampling is not the bound this spec reads').toBeTruthy();
  expect(
    flix.match(/if \(at >= length\)\s*\n?\s*Nil/),
    'the Flix sampling no longer stops where the TypeScript sampling stops',
  ).toBeTruthy();
});

/**
 * Of two stretches equally near, the first is the one kept — which is the only reason
 * two runs over the same files print the same `our-side` figure. A `<=` in either
 * language moves the reported place to the last tie rather than the first and leaves
 * every mean the same, so nothing but a comparison sees it.
 */
test('a tie between two near stretches falls on the first in either language', () => {
  expect(node.match(/if \(near\.distance < best\.distance\)/), 'the TypeScript walk no longer keeps the first nearest').toBeTruthy();
  expect(flix.match(/if \(on#distance < held#distance\)/), 'the Flix walk no longer keeps the first nearest').toBeTruthy();
});

/**
 * A stretch of nought length — two of the same place, which a survey full of
 * doublings has — is a place rather than a stretch: the nearest place on it is its own
 * start, and nothing divides by its nought length.
 */
test('a zero-length stretch is a place rather than a stretch in either reading', () => {
  expect(node.match(/const at = span === 0 \? 0 :/), 'the TypeScript projection does not settle a nought-length stretch').toBeTruthy();
  expect(flix.match(/let along = if \(span == 0\.0\) 0\.0 else/), 'the Flix projection does not settle a nought-length stretch').toBeTruthy();
});

/**
 * The nearest place is reported at the metre it stands at, between the metres of the
 * stretch it was found on — not at that stretch's start. The difference is smaller than
 * the spacing the file was written at, which is exactly the size of the number the
 * report prints third, and a reading that snaps to the start reports `our-side 450.0 m`
 * where the other reports `450.3 m`.
 */
test('the near place is measured between the metres of its stretch, not at its start', () => {
  expect(
    node.match(/metres: metres\[i - 1\] \+ \(metres\[i\] - metres\[i - 1\]\) \* near\.at/),
    'the TypeScript reading reports a stretch start, not a place',
  ).toBeTruthy();
  expect(
    flix.match(/stretch#metres \+ \(\(stretch#after - stretch#metres\) \* on#at\)/),
    'the Flix reading reports a stretch start, not a place',
  ).toBeTruthy();
});

/**
 * The place along a line is found by walking the line's own metres and stopping at the
 * first stretch whose end passes it, the last stretch excepted: a place beyond the
 * line's end falls on that last stretch rather than past the last point. Both languages
 * state the bound as `length - 1`; the Flix walk states it as `length - 2` because it
 * counts from the stretch rather than from the metre.
 */
test('the walk along a line stops at its last stretch in either reading', () => {
  expect(node.match(/while \(i < metres\.length - 1 && metres\[i\] < s\)/), 'the TypeScript walk has a bound this spec cannot read').toBeTruthy();
  expect(flix.match(/walk\(points, metres, s, 1, List\.length\(metres\) - 2\)/), 'the Flix walk has a bound this spec cannot read').toBeTruthy();
  expect(
    flix.match(/if \(at <= last and far < s\)/),
    'the Flix walk no longer excepts the last stretch, which is where a place past the end falls',
  ).toBeTruthy();
});

/**
 * The claims a kept file makes of its outline, checked in the order the profile makes
 * them and refused in the same words. These sentences are what a person reads when a
 * geometry they did not write is refused, and the two readings of them are not compared
 * to each other by any compiler.
 */
test('a file whose outline contradicts itself is refused in one set of words', () => {
  for (const sentence of [
    'no outline feature',
    'which is not a line this repository reads',
    'the outline holds no points to draw',
    'the outline publishes no metres',
    'metres for',
    'metres go backwards at point',
    'the geometry holds no pit lane',
    'the pit lane holds no coordinates',
  ]) {
    expect(kept, `the TypeScript reading does not say "${sentence}" where the Flix reading does`).toContain(sentence);
    expect(file, `the Flix reading does not say "${sentence}" where the TypeScript reading does`).toContain(sentence);
  }
});

/**
 * Which kinds of line a file may name as its `basis`: the two lists are what decides
 * whether a kept atlas line is readable at all, and a basis known to one reading and
 * not the other is a file the diff refuses and the atlas command happily writes.
 */
test('both readings know the same kinds of line', () => {
  const bases = (text: string) => [...text.matchAll(/"(?:osm-centreline|measured-midline)"/g)].map((m) => m[0]);
  const surveyed = bases(kept);
  expect(surveyed.length, 'the TypeScript reading lists no bases to compare').toBeGreaterThan(1);
  expect(bases(file), 'the Flix reading knows a different set of bases').toEqual(surveyed);
});

/**
 * A metre is printed the way the files that hold it were written: `5515` and not
 * `5515.0`, `1.2 m` and not `1.2000000000000002 m`. Java prints a `Float64` with its
 * decimal always present, so a command that interpolates what it computed rewrites
 * every whole metre in a file — and the overlay this command writes is compared to the
 * one the TypeScript tool writes, byte for byte, by whoever re-lays it.
 */
test('a distance is printed as the files that hold it were printed', () => {
  // The rounding is the one `toFixed` states: nearest at that many decimals, ties away
  // from zero, which a `+ 0.5` and a truncation does.
  expect(
    printed.match(/let scaled = Float64\.truncateToInt64\(\(metres \* Int64\.toFloat64\(scale\)\) \+ 0\.5\)/),
    'the Flix printing no longer rounds the way a decimal print rounds',
  ).toBeTruthy();
  for (const figure of ['apart#mean', 'apart#worst#distance', 'apart#worst#bMetres']) {
    expect(command, `the report prints ${figure} as a Float64, which is a changed file`).toContain(
      `Util.Format.fixed(1, ${figure})`,
    );
  }
  expect(
    command,
    'the report quotes a place along a line with a decimal, which the TypeScript tool does not',
  ).toContain('Util.Format.fixed(0, apart#worst#aMetres)');
});

/**
 * A sentence quotes a file's own figure without forcing decimals on it: a line whose
 * metres end at nought is refused as one that `ends at 0 m`, which is what the
 * TypeScript reading says and what every test of that reading matches.
 */
test('a figure quoted from a file is spelled as the file spelled it', () => {
  expect(node, 'the TypeScript reading no longer quotes the length it refused').toContain(
    'its own metres end at ${length} m',
  );
  expect(flix, 'the Flix reading quotes a length the Java way, with a decimal on it').toContain(
    'its own metres end at ${Util.Format.spelled(length)} m',
  );
  expect(
    printed.match(/if \(Int64\.toFloat64\(asWhole\) == metres\) "\$\{asWhole\}" else "\$\{metres\}"/),
    'the Flix printing no longer drops the decimal from a whole figure',
  ).toBeTruthy();
});

/**
 * The sphere every metre here is measured on. Four sources hold the number — the
 * survey's, the probe's, the drawing's and this comparison's — and no compiler reads two
 * of them together. `circuit-overpass.spec.ts` holds the probe's copy to the survey's; a
 * comparison laid on another sphere measures a different circuit and prints it in metres
 * that look like metres.
 */
test('both comparisons are laid on the sphere every drawing is measured on', () => {
  const radius = (text: string, where: string) => {
    const found = text.match(/(63\d{5}(?:\.\d+)?)/);
    expect(found, `${where} states no earth radius in metres`).toBeTruthy();
    return Number(found![1]);
  };
  const surveyed = radius(survey.split('export const earthRadius')[1]!.split('\n')[0]!, 'circuit-geometry.ts');
  const measured = radius(flix.split('def earthMetres')[1]!.split('\n')[0]!, 'circuits/geometry/src/Apart.flix');
  const drawn = radius(readSource('package/src/Motorsport/Circuit/Geodesy.elm'), 'Motorsport.Circuit.Geodesy');
  expect(measured, 'the geometry project measures on a sphere the survey does not').toBe(surveyed);
  expect(drawn, 'the drawing projects through a sphere its own surveys are not measured on').toBe(surveyed);
});

/**
 * One plane, taken about the mean latitude of the places of *both* lines: neither line is
 * drawn at a scale of its own, which is the only reason a survey stretched to a published
 * lap length and a line measured at its own are compared place against place. The mean,
 * the east-west scale and the south-running `y` are one arithmetic read in either
 * language. Where the two call it differs is what each reads rather than how it projects:
 * the atlas reading throws its pit lane into the mean and the diff reads no pit lane.
 */
test('both lines are laid on one plane about the places of both', () => {
  expect(
    survey.match(/const parallel = points\.reduce\(\(sum, p\) => sum \+ p\.lat, 0\) \/ points\.length;/),
    'the TypeScript projection no longer means the latitudes it was handed',
  ).toBeTruthy();
  expect(
    flix.match(/List\.foldLeft\(\(total, place\) -> total \+ place#lat, 0\.0, places\) \/ Int32\.toFloat64\(List\.length\(places\)\)/),
    'the Flix projection no longer means the latitudes it was handed',
  ).toBeTruthy();
  expect(survey, 'the TypeScript east is no longer scaled at the parallel').toContain(
    'x: lon * (Math.PI / 180) * earthRadius * east',
  );
  expect(flix, 'the Flix east is no longer scaled at the parallel').toContain(
    'x = place#lon * radians() * earthMetres() * cos(parallel)',
  );
  expect(survey, 'the TypeScript y no longer runs south').toContain('y: -lat * (Math.PI / 180) * earthRadius');
  expect(flix, 'the Flix y no longer runs south').toContain('y = 0.0 - (place#lat * radians() * earthMetres())');

  // The places the mean is taken over are the two lines' together, at both calls.
  expect(atlas.match(/projection\(\[\s*\.\.\.coords\.map\(onEarth\),/), 'the atlas reading no longer projects the two lines together').toBeTruthy();
  expect(
    command.match(/Apart\.parallelOf\(List\.flatMap\(line -> line#coords, lines\)\)/),
    'the diff no longer projects the two lines together',
  ).toBeTruthy();
});

/**
 * Two deliberate differences, pinned so that a third reading of them is a decision
 * rather than a slip. A spacing the reader cannot have meant is echoed as the word they
 * typed in Flix and as the coerced `NaN` in TypeScript; and a path is left as it was
 * typed in Flix and resolved against the working directory in TypeScript, which the
 * flake's runner restores by another means.
 *
 * These are read out of `circuits/geometry-diff.ts` — where the asking of two paths
 * stayed when the comparison was split out of it — and not out of `apartness.ts`, which
 * the atlas command reads and the arguments never reach.
 */
test('the two readings differ where they are known to', () => {
  expect(asking.match(/args\.every = Number\(argv\[\+\+at\]\)/), 'the TypeScript reading no longer coerces a distance').toBeTruthy();
  expect(asking).toContain('is not a distance');
  expect(command).toContain('\\"${spelled}\\" is not a distance');
  expect(command.match(/paths = paths, every = asked/), 'the Flix reading no longer keeps paths as they were typed').toBeTruthy();
  expect(asking).toContain('args.paths.push(resolve(argv[at]))');
});

/**
 * The two commands, read the way `geometry-contract.spec.ts` reads the Node tools'
 * registrations: a flake app whose directory or entry point has moved fails at whoever
 * typed it, in a shell, with nothing to say why.
 */
test("the flake's geometry commands reach the sources they run", () => {
  const registered = [...readSource('flake.nix').matchAll(/mkGeometryApp "([\w-]+)"/g)].map((m) => m[1]);
  expect(registered.sort(), 'the flake registers a different set of geometry commands than these').toEqual([
    'geometry-diff',
    'geometry-diff-test',
  ]);
  const main = readSource('circuits/geometry/src/Main.flix');
  expect(main, 'nix run .#geometry-diff runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Diff.exitCode(rest))',
  );
  expect(main, 'the commands Main names and the commands it dispatches are not the same').toContain('"diff" :: Nil');
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
  const held: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(new URL(`../../circuits/geometry/${dir}`, import.meta.url), { withFileTypes: true })) {
      const path = `${dir}/${entry.name}`;
      if (lstatSync(new URL(`../../circuits/geometry/${path}`, import.meta.url)).isSymbolicLink()) {
        expect(true, `${path} links out of the geometry project, which shares no source with anything`).toBe(false);
      } else if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('.flix')) held.push(path.replace(/^\/+/, ''));
    }
  };
  walk('src');

  expect(held.sort(), 'the geometry project holds sources this spec does not know').toEqual([
    'src/Apart.flix',
    'src/Diff.flix',
    'src/Geometry.flix',
    'src/Main.flix',
    'src/Util/Files.flix',
    'src/Util/Format.flix',
  ]);

  const toml = readSource('circuits/geometry/flix.toml');
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
  expect(version('circuits/geometry/flix.toml'), 'the geometry project is not on the CLI\'s Flix version').toBe(
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
  const reader = readSource('circuits/geometry/src/Util/Files.flix');
  expect(reader, 'the geometry project no longer asks for the directory it was run from').toContain(
    'Env.getVar("GEOMETRY_FROM")',
  );
});
