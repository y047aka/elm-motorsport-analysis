import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync } from 'node:fs';
import { circuit as cota } from '../../circuits/cota/circuit.ts';
import { circuit as leMans } from '../../circuits/le_mans/circuit.ts';

import { readSource } from './helpers';

/**
 * One set of readings, held in two languages, and no compiler sees both.
 *
 * The comparison is `circuits/apartness.ts`, which the atlas command samples, and
 * `circuits/src/Apart.flix`, which the diff samples. The survey is
 * `circuits/circuit-geometry.ts`, which reads an Overpass answer, chains a relation's ways into
 * a lap, stretches it to the length the circuit publishes and writes the file the app serves,
 * and `Survey.flix` with `Write.flix`, which do the same over a kept answer — `nix run
 * .#geometry-survey` fails unless the bytes it lays are the bytes the app serves. Asking
 * OpenStreetMap is Flix's now too; the TypeScript half asks only the regeneration fence's
 * `--freeze`, and `circuit-overpass.spec.ts` is where the facts of that asking are read
 * out of every spelling of it.
 *
 * A parting is silent in both directions. The apartness of two lines sampled on another bound is
 * a mean within a few metres of the truth, which reads as a reading of two lines that in fact
 * disagree; a survey that parts is louder, and audible only where a survey is run — which is
 * over two kept answers. So the bound of each loop, which stretch a tie falls on, the order the
 * claims are written in, the sphere both are laid on and the tenth a metre is kept to are read
 * out of both sources here, the way `circuit-overpass.spec.ts` reads the Overpass facts out of
 * both sides of the Flix/TypeScript line.
 *
 * Nothing here needs a browser.
 */

const node = readSource('circuits/apartness.ts');
const kept = readSource('circuits/geometry-file.ts');
const drift = readSource('circuits/geometry-drift.ts');
const allowance = readSource('circuits/timing-line.ts');
const survey = readSource('circuits/circuit-geometry.ts');
const atlas = readSource('circuits/atlas-geometry.ts');
const flix = readSource('circuits/src/Apart.flix');
const file = readSource('circuits/src/Geometry.flix');
const command = readSource('circuits/src/Diff.flix');
const printed = readSource('circuits/src/Util/Format.flix');
const config = readSource('circuits/src/Circuit.flix');
const chained = readSource('circuits/src/Survey.flix');
const writer = readSource('circuits/src/Write.flix');
const main = readSource('circuits/src/Main.flix');

const authored: Record<string, typeof cota> = { cota, le_mans: leMans };

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
 * Every source the geometry project compiles — eleven of Flix and seven of tests, which is
 * what the project is asserted to hold — for the reading of their text alone: a word a
 * database is named by would arrive in a source file and not in a build product.
 */
const everySource = project.map(readSource);

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
 * A metre is printed the way the files that hold it were written: `5515` and not `5515.0`,
 * `1.2 m` and not `1.2000000000000002 m`. Java prints a `Float64` with its decimal always
 * present, so a command that writes a kept file or an overlay cannot interpolate what it
 * computed, or every whole metre in the file is a changed line.
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
    'the report no longer quotes a place along a line at whole metres, as the files spell it',
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
  const measured = radius(flix.split('def earthMetres')[1]!.split('\n')[0]!, 'circuits/src/Apart.flix');
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
 * The two commands, read the way `geometry-contract.spec.ts` reads the Node tools'
 * registrations: a flake app whose directory or entry point has moved fails at whoever
 * typed it, in a shell, with nothing to say why.
 */
test("the flake's geometry commands reach the sources they run", () => {
  const registered = [...readSource('flake.nix').matchAll(/mkGeometryApp "([\w-]+)"/g)].map((m) => m[1]);
  expect(registered.sort(), 'the flake registers a different set of geometry commands than these').toEqual([
    'geometry-diff',
    'geometry-diff-test',
    'geometry-fetch',
    'geometry-survey',
    'geometry-write',
  ]);
  // Each app hands its subcommand word to the jar, so a renamed subcommand is a flake app
  // that answers with a usage where the reader expected a report.
  const flake = readSource('flake.nix');
  for (const [app, word] of [
    ['geometry-diff', 'diff'],
    ['geometry-fetch', 'fetch'],
    ['geometry-survey', 'survey'],
    ['geometry-write', 'write'],
  ]) {
    expect(flake, `nix run .#${app} no longer hands the jar the "${word}" subcommand`).toContain(
      `mkGeometryApp "${app}" "flix run -- ${word} \\"$@\\""`,
    );
  }
  expect(main, 'nix run .#geometry-diff runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Diff.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry-survey runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Write.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry-fetch runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Fetch.exitCode(rest))',
  );
  expect(main, 'nix run .#geometry-write runs a main that hands the reader its arguments to nothing').toContain(
    'Exit.exit(Fetch.writeExitCode(rest))',
  );
  expect(main, 'the commands Main names and the commands it dispatches are not the same').toContain(
    '"diff" :: "fetch" :: "survey" :: "write" :: Nil',
  );
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
    'circuits/src/Circuit.flix',
    'circuits/src/Diff.flix',
    'circuits/src/Fetch.flix',
    'circuits/src/Geometry.flix',
    'circuits/src/Main.flix',
    'circuits/src/Overpass.flix',
    'circuits/src/Survey.flix',
    'circuits/src/Util/Files.flix',
    'circuits/src/Util/Format.flix',
    'circuits/src/Write.flix',
    'circuits/test/TestApart.flix',
    'circuits/test/TestDiff.flix',
    'circuits/test/TestFetch.flix',
    'circuits/test/TestGeometry.flix',
    'circuits/test/TestOverpass.flix',
    'circuits/test/TestSurvey.flix',
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
 * One circuit's config, in the language the Flix survey is written in. The two records are
 * authored apart — the TypeScript one is what the survey and the atlas reading are given,
 * the Flix one is what `geometry-survey` is given — and every figure in them is a fact about
 * a circuit, which is one fact twice over with no compiler between the two copies.
 */
function flixConfig(word: string): string {
  const claims = new RegExp(`word\\s+=\\s+"${word}"`);
  const body = config
    .split('\n    def ')
    .slice(1)
    .find((each) => claims.test(each));
  if (!body) throw new Error(`circuits/src/Circuit.flix authors no circuit the word "${word}" answers to`);
  return body.split('\n    }')[0];
}

/** A figure the Flix config states, with Flix's own width off the literal. */
function figure(source: string, key: string): string {
  const stated = source.match(new RegExp(`\\b${key}\\s*=\\s*([^,\\n]+)`));
  expect(stated, `the Flix config states no ${key}`).toBeTruthy();
  return stated![1].trim().replace(/i64$/, '');
}

const lineOf = (source: string, key: string): string | undefined =>
  source.split('\n').find((each) => each.includes(`${key} =`))?.trim();

test("a circuit's figures are authored once and held in either language", () => {
  for (const [word, circuit] of Object.entries(authored)) {
    const held = flixConfig(word);

    expect(Number(figure(held, 'relation')), `${word}: the two surveys read different relations`).toBe(
      circuit.relation,
    );
    expect(figure(held, 'word'), `${word}: the Flix survey draws it by another word`).toBe(`"${circuit.slug}"`);
    expect(figure(held, 'timedFrom'), `${word}: the two surveys start from different lines`).toBe(
      `"${circuit.finishRole}"`,
    );
    expect(Number(figure(held, 'lap')), `${word}: the two surveys stretch to different laps`).toBe(
      circuit.lapLength,
    );
    expect(figure(held, 'file'), `${word}: the Flix survey writes somewhere else`).toBe(`"${circuit.geojson}"`);
    expect(figure(held, 'survey'), `${word}: the two surveys read different answers`).toBe(`"${circuit.survey}"`);

    const timing = lineOf(held, 'timingLine');
    expect(timing, `${word}: the Flix config says nothing about the timing line`).toBeTruthy();
    if (circuit.timingLine) {
      expect(
        Number(timing!.match(/lat = (-?[\d.]+)/)?.[1]),
        `${word}: the Flix line's latitude is not the published one`,
      ).toBe(circuit.timingLine.lat);
      expect(
        Number(timing!.match(/lon = (-?[\d.]+)/)?.[1]),
        `${word}: the Flix line's longitude is not the published one`,
      ).toBe(circuit.timingLine.lon);
      expect(
        Number(timing!.match(/within = Some\(([\d.]+)\)/)?.[1]),
        `${word}: the Flix line allows another distance than the published one`,
      ).toBe(circuit.timingLine.within ?? 10);
    } else {
      expect(timing, `${word}: the Flix config times from a line the circuit does not publish`).toContain(
        'timingLine = None',
      );
    }

    const sectors = circuit.sectors;
    if (sectors.kind === 'published') {
      expect(figure(held, 'source'), `${word}: the two configs credit different maps`).toBe(`"${sectors.source}"`);
      const stretches = held.match(/stretches = ([^\n]+)/);
      expect(stretches, `${word}: the Flix config publishes no stretches`).toBeTruthy();
      const every = stretches![1].split('::').map((each) => each.trim()).filter((each) => each !== 'Nil');
      expect(
        every.map((each) => Number(each)),
        `${word}: the two configs time the lap at different lines`,
      ).toEqual(sectors.stretches);
    } else {
      expect(held, `${word}: the Flix config publishes stretches a per-season map has`).toContain('published = None');
      expect(
        held,
        `${word}: the Flix config does not carry the reason a round of that circuit is refused`,
      ).toContain(`"${sectors.reason}"`);
    }
  }

  // How far a relation's node may stand from the published line and still be it: the map's
  // own crosshair, which is a fact about the map and not about a language.
  expect(
    Number(config.match(/pub def nodeWithin\(\): Float64 = ([\d.]+)/)?.[1]),
    'the Flix crosshair is not the crosshair the TypeScript survey allows',
  ).toBe(Number(allowance.match(/export const nodeWithin = ([\d.]+)/)?.[1]));
});

test('the two writers lay the same claims, in one order, in one file', () => {
  const outline = survey.split('export function geoJsonString')[1].split('const pitLane = feature(')[0];
  const claimed = [...outline.matchAll(/^      ([a-z_]+):/gm)].map((m) => m[1]);
  expect(claimed, 'the kept files claim these things in this order; read them off the writer').toEqual([
    'role',
    'circuit',
    'basis',
    'source',
    'license',
    'surveyed_at',
    'direction',
    'lap_length_m',
    'surveyed_length_m',
    'sectors',
    'frame',
    'metres',
  ]);

  const claims = writer.split('def authored(circuit: Circuit')[1].split('/// The pit lane')[0];
  expect(
    [...claims.matchAll(/\("([a-z_]+)",/g)].map((m) => m[1]),
    'the Flix writer lays the claims in another order than the file was written in',
  ).toEqual(claimed);

  const pit = survey.split('const pitLane = feature(')[1].split('\n')[1];
  expect(
    [...writer.split('def pitOf(circuit: Circuit')[1].split('/// The kind of line')[0].matchAll(/\("([a-z_]+)",/g)].map(
      (m) => m[1],
    ),
    'the Flix writer says something of the pit lane the TypeScript writer does not',
  ).toEqual([...pit.matchAll(/([a-z_]+): /g)].map((m) => m[1]));

  // The file's own shape, which both writers have to hit byte for byte: the header, one
  // Feature per line of the two, and a geometry whose coordinates are on the one line.
  expect(survey).toContain('{"type": "FeatureCollection", "features": [');
  expect(writer).toContain('{\\"type\\": \\"FeatureCollection\\", \\"features\\": [');
  expect(survey).toContain('JSON.stringify({ type: "LineString", coordinates })');
  expect(writer).toContain('{\\"type\\":\\"LineString\\",\\"coordinates\\":');

  // A claim a circuit cannot make is no line at all rather than a `null` one: Le Mans has no
  // stamp to write and no published map, and a file that said `"sectors": null` would read
  // as a circuit that publishes empty lines.
  expect(survey).toContain('.filter(([, value]) => value !== undefined)');
  expect(claims).toContain('Option.map(stamped -> ("surveyed_at", text(stamped)), geometry#surveyedAt)');
  // ... and only a circuit that publishes one map sends its timing lines, whichever kind of
  // `sectors` the config holds.
  expect(survey).toContain('circuit.sectors.kind === "published"');
  expect(claims).toContain('Option.map(lines -> ("sectors", published(lines)), circuit#sectors#published)');
});

test('a metre is kept to the tenth the survey is held at in either pipeline', () => {
  expect(survey, 'the TypeScript survey no longer keeps a metre to a tenth').toContain('return Math.round(n * 10) / 10;');
  expect(chained, 'the Flix survey keeps a tenth the Java way, which sends a positive half down').toContain(
    'Int64.toFloat64(Float64.truncateToInt64((metres * tenths()) + 0.5)) / tenths()',
  );
  expect(Number(chained.match(/pub def tenths\(\): Float64 = ([\d.]+)/)?.[1]), 'the Flix tenth is not a tenth').toBe(
    Number(survey.match(/Math\.round\(n \* ([\d.]+)\) \/ ([\d.]+)/)?.[1]),
  );

  // A number that would print differently in the two writers is a drawing that moved by a
  // digit: Flix spells a whole float `5515.0` where JavaScript spells `5515`, and neither
  // reaches the exponential form a metre, a latitude or a longitude never gets near.
  expect(survey).toContain('JSON.stringify(value)');
  expect(writer).toContain('if (String.endsWith({suffix = ".0"}, spelled)) String.dropRight(2, spelled) else spelled');

  // The bound the thinning stops at is a drawing's, not a language's: it is the reason a
  // kept file holds the points it holds.
  expect(
    Number(survey.match(/^const tolerance = ([\d.]+);/m)?.[1]),
    'the thinning tolerance is not the same in the two surveys',
  ).toBe(Number(chained.match(/pub def tolerance\(\): Float64 = ([\d.]+)/)?.[1]));
});

test('the thinning splits a lap at its own middle and turns on the first of two ties', () => {
  // A lap is closed, so its first point is its last; thinning the whole thing would let that
  // one point be the pivot of both halves at once.
  expect(survey).toContain('const half = Math.floor(lapPoints.length / 2);');
  expect(chained).toContain('let half = List.length(lapPoints) / 2;');
  expect(survey).toContain(
    '...simplify(lapPoints, 0, half).slice(0, -1),\n    ...simplify(lapPoints, half, lapPoints.length - 1),',
  );
  expect(chained).toContain(
    'List.append(withoutLast(simplify(points, 0, half)), simplify(points, half, lastIndex(points)))',
  );

  expect(survey).toContain('if (furthest <= tolerance) return [from, to];');
  expect(chained).toContain('if (best <= tolerance() or at < 0) lo :: hi :: Nil');
  // Strictly further, so the first of two points equally far off the chord is the one kept:
  // a tie taken the other way is a survey that keeps another point, anywhere on the lap.
  expect(survey).toContain('if (d > furthest) {');
  expect(chained).toContain('if (distance > best)');
});

test('the lap is stretched by one factor taken off its own surveyed length', () => {
  expect(survey).toContain('const stretch = circuit.lapLength / surveyed[surveyed.length - 1];');
  expect(chained).toContain('let stretch = circuit#lap / Option.getWithDefault(0.0, List.last(surveyed));');
  expect(survey).toContain('const metres = surveyed.map((m) => m * stretch);');
  expect(chained).toContain('let metres = List.map(each -> each * stretch, surveyed);');

  // The cumulative sum runs each line forwards from nought, which is the only reason the
  // surveyed length a file carries is reproducible by another program at all.
  expect(survey).toContain('out.push(out[i - 1] + Math.hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y));');
  expect(chained).toContain('let step = total + Apart.hypot(one#x - ahead#x, one#y - ahead#y);');

  // The corner both are measured from is the north-west of every place of both lines, and
  // `y` runs south, which is why a positive shoelace is a clockwise lap in either language.
  expect(survey).toContain('lat: Math.max(...points.map((p) => p.lat)),');
  expect(survey).toContain('lon: Math.min(...points.map((p) => p.lon)),');
  expect(chained).toContain('lat = if (place#lat > corner#lat) place#lat else corner#lat,');
  expect(chained).toContain('lon = if (place#lon < corner#lon) place#lon else corner#lon');
  expect(survey).toContain('return sum > 0 ? "clockwise" : "counter_clockwise";');
  expect(chained).toContain('if (shoelace(points) > 0.0) clockwise() else counterClockwise()');
});

test('a survey that cannot be chained is refused in one set of words', () => {
  for (const sentence of [
    'the answer holds no relation',
    'tags no member with role',
    'which the answer does not hold',
    'the relation holds no way the lap can start from',
    'ways left out of the chain',
    'nearest end',
    'where the chain stopped',
    'driven the other way',
    'the lap does not close',
    'the chain ended at a node the answer does not hold',
    "The relation's lines:",
  ]) {
    expect(survey, `the TypeScript survey no longer says "${sentence}" where the Flix survey does`).toContain(sentence);
    expect(chained, `the Flix survey no longer says "${sentence}" where the TypeScript survey does`).toContain(sentence);
  }

  // The timing line's own refusal is one module's, and both surveys reach it for the same
  // relation member: a line further than the map's crosshair is another line.
  expect(allowance).toContain('m from the published timing line, which is not within');
  expect(chained).toContain('m from the published timing line, which is not within');
});

test('a byte comparison exempts nothing, where a property comparison exempts the stamp', () => {
  // The regeneration fence compares two parsed files property by property and lets
  // `surveyed_at` move, because a regeneration that asks OpenStreetMap now takes a newer
  // survey. The Flix comparison is of bytes, and has nothing to exempt: it reads the very
  // answer whose stamp the property carries, so the stamp it writes is the stamp it reads.
  expect(drift).toContain('if (key === "surveyed_at") continue;');
  expect(writer).toContain('`surveyed_at` needs no');
  expect(writer).toContain('written == kept');
});

test('the Flix survey is fenced against the bytes the app serves', () => {
  const workflow = readSource('.github/workflows/test.yml');
  for (const circuit of Object.keys(authored)) {
    expect(
      workflow,
      `CI no longer asks whether the Flix survey lays ${circuit}'s kept geometry`,
    ).toContain(`nix run .#geometry-survey -- ${circuit}`);
  }
  expect(workflow, 'CI no longer runs the geometry project').toContain('nix run .#geometry-diff-test');
  // A CI run compares; a run that writes is the reader's own, and a `--write` in CI would
  // make the fence pass by rewriting what it is meant to be fencing.
  for (const step of workflow.match(/nix run \.#geometry-survey[^\n]*/g) ?? []) {
    expect(step, `CI writes ${step.trim()} rather than comparing it`).not.toContain('--write');
  }
});
