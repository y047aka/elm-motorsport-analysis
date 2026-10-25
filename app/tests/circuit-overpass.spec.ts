import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync } from 'node:fs';

import { readSource } from './helpers';

/**
 * OpenStreetMap is asked from two languages, and no compiler sees the other.
 *
 * The pipeline that writes a circuit's geometry asked it in TypeScript
 * (`circuits/circuit-geometry.ts`), the probe that decides which relation a
 * circuit is asks it in Flix (`circuits/probe/`, `nix run .#geometry-probe`), and
 * the pipeline asks it in Flix too now (`circuits/src/Overpass.flix`, `nix run
 * .#geometry-fetch`) — the TypeScript spelling is what the atlas reading and the
 * regeneration fence still import, so the four facts about the meeting are held
 * three times: which runners there are and in which order, what a run
 * calls itself, how many times each runner is asked, and how long one that just
 * failed is left alone.
 *
 * None of those fail loudly when they part. A runner dropped from one list sends
 * half the runs to a busy machine that the other language knows a second of; a
 * user agent that differs is a request whose operator cannot tell a probe from a
 * flood; and a backoff that shrinks to nothing is a retry loop aimed at a runner
 * that was already down. So the four are read out of both sources and compared,
 * the way `circuit-timing-map.spec.ts` reads a circuit's timing figures out of
 * both sides of the Flix/TypeScript line, and the sphere a probe's metres are
 * measured on is read out of all three languages that use it.
 *
 * Nothing here needs a browser.
 */

const node = readSource('circuits/circuit-geometry.ts');
const flix = readSource('circuits/probe/src/Overpass.flix');
const pipeline = readSource('circuits/src/Overpass.flix');
const candidates = readSource('circuits/probe/src/Candidates.flix');
const command = readSource('circuits/probe/src/Probe.flix');

/** Everything the probe compiles, for the readings that ask only of its text. */
const everySource = [node, flix, candidates, command, readSource('circuits/probe/src/Main.flix')];

/** The runners, in the order each language walks them. */
function nodeRunners(): string[] {
  const body = node.split('const overpassRunners = [')[1]?.split(']')[0];
  expect(body, 'circuit-geometry.ts declares no overpassRunners to compare').toBeTruthy();
  return [...body!.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
}

function flixRunners(): string[] {
  return flixRunnersIn(flix, 'the probe');
}

/** The same reading of any Flix spelling of the asking. */
function flixRunnersIn(source: string, where: string): string[] {
  const body = source.split('pub def runners()')[1]?.split(':: Nil')[0];
  expect(body, `${where} declares no runners() to compare`).toBeTruthy();
  return [...body!.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
}

/** A `pub def name(): T = ...` in the probe, cut at the blank line that ends it. */
function flixDef(name: string): string {
  return flixDefIn(flix, name, 'the probe');
}

/** The same reading of any Flix spelling of the asking. */
function flixDefIn(source: string, name: string, where: string): string {
  const body = source.split(`pub def ${name}`)[1]?.split('\n\n')[0];
  expect(body, `${where} states no ${name}() for this spec to read`).toBeTruthy();
  return body!;
}

function quoted(text: string, where: string): string {
  const found = text.match(/"([^"]+)"/);
  expect(found, `${where} states no string to read`).toBeTruthy();
  return found![1];
}

test('both languages ask the same runners, in the same order', () => {
  const asked = nodeRunners();
  expect(asked.length, 'the pipeline asks no Overpass runner').toBeGreaterThan(1);
  expect(flixRunners(), 'the probe walks a different list of Overpass runners, or the same ones in another order').toEqual(
    asked,
  );
});

test('a run names itself the same in either language', () => {
  const agent = quoted(node.split('const userAgent = ')[1]!, 'circuit-geometry.ts userAgent');
  expect(
    quoted(flixDef('userAgent'), 'the probe userAgent'),
    'a runner reading a log cannot tell this probe from that pipeline, and neither can a rate limiter',
  ).toBe(agent);
});

/**
 * Each runner is asked twice, and the wait before the next request is a function
 * of which attempt just failed. TypeScript spells it `attempt * 4000` and Flix
 * `4000 * attempt`; the multiplication is the fact, and the order of the factors
 * is nothing.
 */
test('each runner is asked twice, and one that failed is left alone by the same arithmetic', () => {
  const perRunner = Number(node.split('attempt <= ')[1]?.match(/^(\d+)/)?.[1]);
  expect(perRunner, 'circuit-geometry.ts asks each runner an unreadable number of times').toBe(2);
  expect(Number(flixDef('tries').match(/= (\d+)/)?.[1]), 'the probe asks each runner a different number of times').toBe(
    perRunner,
  );

  const nodeUnit = Number(node.split('await sleep(')[1]?.match(/^attempt \* (\d+)/)?.[1]);
  const flixUnit = Number(flixDef('backoff').match(/Duration\.of\((\d+) \* attempt/)?.[1]);
  expect(nodeUnit, 'the pipeline backs off by an amount this spec cannot read').toBeGreaterThan(0);
  expect(flixUnit, 'the probe backs off by an amount this spec cannot read').toBe(nodeUnit);
});

/**
 * The pipeline's own Flix asking, read against the same two spellings. It is a
 * third holder of the four facts rather than a new kind of fact: the Flix
 * survey spells its runners, its name, its tries and its backoff in a file of
 * its own, and a rename of any one of them on one side is a run that visits a
 * runner the others steer around.
 */
test('the Flix pipeline asks the same runners, of its own name, the same number of times', () => {
  const asked = nodeRunners();
  expect(
    flixRunnersIn(pipeline, 'the Flix pipeline'),
    'the Flix pipeline walks a different list of Overpass runners, or the same ones in another order',
  ).toEqual(asked);

  const agent = quoted(node.split('const userAgent = ')[1]!, 'circuit-geometry.ts userAgent');
  expect(
    quoted(flixDefIn(pipeline, 'userAgent', 'the Flix pipeline'), 'the Flix pipeline userAgent'),
    'a runner reading a log cannot tell this probe from this survey, and neither can a rate limiter',
  ).toBe(agent);

  const perRunner = Number(node.split('attempt <= ')[1]?.match(/^(\d+)/)?.[1]);
  expect(
    Number(flixDefIn(pipeline, 'tries', 'the Flix pipeline').match(/= (\d+)/)?.[1]),
    'the Flix pipeline asks each runner a different number of times',
  ).toBe(perRunner);

  const flixUnit = Number(flixDef('backoff').match(/Duration\.of\((\d+) \* attempt/)?.[1]);
  const pipelineUnit = Number(flixDefIn(pipeline, 'backoff', 'the Flix pipeline').match(/Duration\.of\((\d+) \* attempt/)?.[1]);
  expect(pipelineUnit, 'the Flix pipeline backs off by an amount this spec cannot read').toBe(flixUnit);

  for (const sentence of [
    'Overpass answered with something that is not JSON',
    'every Overpass runner failed',
  ]) {
    expect(pipeline, `the Flix pipeline does not say "${sentence}" where the probe does`).toContain(sentence);
  }
});

/**
 * Two sentences a person reads when OpenStreetMap is unwell. They are not compared
 * to each other by any compiler, and a reader who has seen one and searches for
 * the other finds nothing.
 */
test('an answer neither language can read is reported in one set of words', () => {
  for (const sentence of [
    'Overpass answered with something that is not JSON',
    'every Overpass runner failed',
  ]) {
    expect(node, `the pipeline does not say "${sentence}" where the probe does`).toContain(sentence);
    expect(flix, `the probe does not say "${sentence}" where the pipeline does`).toContain(sentence);
  }
});

/**
 * A query is posted as a form body rather than put in a URL: an answer of tens of
 * thousands of points begins as a query long enough to be refused by one of the
 * two, and a 414 from a runner arrives as a failure to reach it.
 */
test('a query goes up as a form field and not as a URL', () => {
  expect(node.split('body: ')[1], 'the pipeline no longer posts the query as a form body').toMatch(
    /new URLSearchParams\(\{ data: query \}\)/,
  );
  expect(flix.split('HttpRequest.postWith')[1], 'the probe puts the query somewhere other than `data=`').toMatch(
    /^\(url, "data=\$\{Net\.HttpLayer\.urlEncode\(question\)\}"/,
  );
});

/**
 * The second question both languages ask: the relation whole and its member ways.
 * `way(r)` is the recursion that brings the ways whose roles the probe counts and
 * whose lines the pipeline chains, so a question that stops short of it asks about
 * a circuit nobody measures. Where the two part is after that — the survey goes on
 * for the nodes to chain (`node(w)`) and the probe stops at the geometry Overpass
 * hands inline — and that is the difference between drawing a lap and lengthening
 * one.
 */
test('the probe asks for the ways the pipeline chains', () => {
  const askedByNode = node.split('askOverpass(`')[1]?.split('`')[0];
  const askedByFlix = command.split('relation(${element#id});')[1]?.split(';')[0];
  expect(askedByNode, 'the pipeline no longer asks a relation and its ways in one query').toBeTruthy();
  expect(askedByNode!, "the pipeline no longer recurses to the relation's ways").toContain('way(r)');
  expect(askedByFlix, "the probe no longer recurses to the relation's ways").toBe('out body');
  expect(command, "the probe asks for nodes, which is a survey's question and not a probe's").not.toContain('node(w)');
});

/**
 * One sphere measures a probe's metres, a survey's metres and the drawing's
 * projection. Three languages hold the number, no compiler reads two of them
 * together, and a probe whose sphere differs from the pipeline's reports a 13.6 km
 * circuit as a 13.7 km one — which is the one reading that decides a config.
 */
test("a probe's metres are measured on the sphere the survey is measured on", () => {
  const radius = (text: string, where: string) => {
    const found = text.match(/(63\d{5}(?:\.\d+)?)/);
    expect(found, `${where} states no earth radius in metres`).toBeTruthy();
    return Number(found![1]);
  };
  const surveyed = radius(node.split('export const earthRadius')[1]!.split('\n')[0]!, 'circuit-geometry.ts');
  const probed = radius(candidates.split('def earthRadius')[1]!.split('\n')[0]!, 'the probe');
  const drawn = radius(readSource('package/src/Motorsport/Circuit/Geodesy.elm'), 'Motorsport.Circuit.Geodesy');
  expect(probed, 'a probe measures its laps on a different sphere from the one the geometry is measured on').toBe(
    surveyed,
  );
  expect(drawn, 'the drawing projects through a different sphere from the one its survey measured').toBe(surveyed);
});

/**
 * The two commands, read the way `geometry-contract.spec.ts` reads the Node tools'
 * registrations: a flake app whose directory or entry point has moved fails at
 * whoever typed it, in a shell, with nothing to say why.
 */
test("the flake's probe commands reach the sources they run", () => {
  const registered = [...readSource('flake.nix').matchAll(/mkProbeApp "([\w-]+)"/g)].map((m) => m[1]);
  expect(registered.sort(), 'the flake registers a different pair of probe commands than these').toEqual([
    'geometry-probe',
    'geometry-probe-test',
  ]);
  expect(
    readSource('circuits/probe/src/Main.flix'),
    'nix run .#geometry-probe runs a main that hands nothing to Probe',
  ).toContain('Probe.exitCode(Env.getArgs())');
});

/**
 * The probe is a second Flix project and shares no source with the CLI: `flix/src`
 * is reached by the timing report through symlinks because the report reads
 * readings that live there, and the probe reads none — every distance in it is
 * taken off an answer about OpenStreetMap, which the CLI has no reason to hold.
 *
 * A link into `flix/src` would compile, which is what makes this worth a test:
 * `Sql.flix` declares an effect that opens no connection, so a project that
 * symlinked it acquires a way to name a database that no command in it can reach,
 * and `flix/flix.toml` resolves a JDBC driver for it.
 */
test('the probe shares no source, resolves no dependency and names no database', () => {
  const held: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(new URL(`../../circuits/probe/${dir}`, import.meta.url), { withFileTypes: true })) {
      const path = `${dir}/${entry.name}`;
      if (lstatSync(new URL(`../../circuits/probe/${path}`, import.meta.url)).isSymbolicLink()) {
        expect(true, `${path} links out of the probe, which shares no source with anything`).toBe(false);
      } else if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('.flix')) held.push(path.replace(/^\/+/, ''));
    }
  };
  walk('src');

  expect(held.sort(), 'the probe holds sources this spec does not know').toEqual([
    'src/Candidates.flix',
    'src/Main.flix',
    'src/Overpass.flix',
    'src/Probe.flix',
  ]);

  const toml = readSource('circuits/probe/flix.toml');
  expect(toml, 'the probe resolves a dependency, so a database is reachable from it').not.toMatch(
    /mvn-dependencies|\[dependencies\]/,
  );
  for (const name of ['SqlRead', 'SqlWrite', 'DbErr', 'Db.Error', 'Jdbc', 'sqlite']) {
    expect(everySource.join('\n'), `the probe names ${name}`).not.toContain(name);
  }

  // One compiler version for the three projects: a source is read by whichever
  // `flix` runs, and a version the others moved past fails for a reason no
  // project states.
  const version = (file: string) => readSource(file).match(/flix\s*=\s*"([^"]+)"/)?.[1];
  expect(version('circuits/probe/flix.toml'), 'the probe is not on the CLI\'s Flix version').toBe(
    version('flix/flix.toml'),
  );
  expect(version('circuits/timing/flix.toml'), 'the two projects under circuits/ are not on one Flix version').toBe(
    version('flix/flix.toml'),
  );
});
