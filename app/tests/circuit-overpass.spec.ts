import { test, expect } from '@playwright/test';
import { readdirSync, lstatSync } from 'node:fs';

import { readSource } from './helpers';

/**
 * OpenStreetMap is asked by two projects in one language, and no compiler sees
 * both.
 *
 * The pipeline that writes a circuit's geometry asks it
 * (`circuits/src/Overpass.flix`, `nix run .#geometry-fetch`), and the probe that
 * decides which relation a circuit is asks it (`circuits/probe/`, `nix run
 * .#geometry-probe`) — the TypeScript asking retired with the regeneration
 * fence's move into the jar, so the four facts about the meeting are held
 * twice: which runners there are and in which order, what a run calls itself,
 * how many times each runner is asked, and how long one that just failed is
 * left alone.
 *
 * None of those fail loudly when they part. A runner dropped from one list
 * sends half the runs to a busy machine that the other project knows a second
 * of; a user agent that differs is a request whose operator cannot tell a
 * probe from a flood; and a backoff that shrinks to nothing is a retry loop
 * aimed at a runner that was already down. So the four are read out of both
 * sources and compared, the way `circuit-timing-map.spec.ts` reads a circuit's
 * timing figures out of the config and out of the report, and the sphere a
 * probe's metres are measured on is read out of every source that uses it — the
 * geometry project's survey, the probe's, and the drawing's.
 *
 * Nothing here needs a browser.
 */

const survey = readSource('circuits/src/Apart.flix');
const flix = readSource('circuits/probe/src/Overpass.flix');
const pipeline = readSource('circuits/src/Overpass.flix');
const candidates = readSource('circuits/probe/src/Candidates.flix');
const command = readSource('circuits/probe/src/Probe.flix');

/** Everything that asks OpenStreetMap, for the readings that ask only of its text. */
const everySource = [pipeline, flix, candidates, command, readSource('circuits/probe/src/Main.flix')];

/** The probe's runners, in the order it walks them. */
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

test('the probe and the pipeline ask the same runners, in the same order', () => {
  const asked = flixRunnersIn(pipeline, 'the pipeline');
  expect(asked.length, 'the pipeline asks no Overpass runner').toBeGreaterThan(1);
  expect(
    flixRunners(),
    'the probe walks a different list of Overpass runners, or the same ones in another order',
  ).toEqual(asked);
});

test('a run names itself the same in either project', () => {
  const agent = quoted(flixDefIn(pipeline, 'userAgent', 'the pipeline'), 'the pipeline userAgent');
  expect(
    quoted(flixDef('userAgent'), 'the probe userAgent'),
    'a runner reading a log cannot tell this probe from that pipeline, and neither can a rate limiter',
  ).toBe(agent);
});

/**
 * Each runner is asked twice, and the wait before the next request is a function
 * of which attempt just failed. The multiplication is the fact, and the order of
 * the factors is nothing — which is why the two spellings are read for the unit
 * rather than for the whole product.
 */
test('each runner is asked twice, and one that failed is left alone by the same arithmetic', () => {
  const perRunner = Number(flixDefIn(pipeline, 'tries', 'the pipeline').match(/= (\d+)/)?.[1]);
  expect(perRunner, 'the pipeline asks each runner an unreadable number of times').toBe(2);
  expect(Number(flixDef('tries').match(/= (\d+)/)?.[1]), 'the probe asks each runner a different number of times').toBe(
    perRunner,
  );

  const pipelineUnit = Number(flixDefIn(pipeline, 'backoff', 'the pipeline').match(/Duration\.of\((\d+) \* attempt/)?.[1]);
  const flixUnit = Number(flixDef('backoff').match(/Duration\.of\((\d+) \* attempt/)?.[1]);
  expect(pipelineUnit, 'the pipeline backs off by an amount this spec cannot read').toBeGreaterThan(0);
  expect(flixUnit, 'the probe backs off by an amount this spec cannot read').toBe(pipelineUnit);
});

/**
 * Two sentences a person reads when OpenStreetMap is unwell. They are not compared
 * to each other by any compiler, and a reader who has seen one and searches for
 * the other finds nothing.
 */
test('an answer neither project can read is reported in one set of words', () => {
  for (const sentence of [
    'Overpass answered with something that is not JSON',
    'every Overpass runner failed',
  ]) {
    expect(pipeline, `the pipeline does not say "${sentence}" where the probe does`).toContain(sentence);
    expect(flix, `the probe does not say "${sentence}" where the pipeline does`).toContain(sentence);
  }
});

/**
 * A query is posted as a form body rather than put in a URL: an answer of tens of
 * thousands of points begins as a query long enough to be refused by a runner,
 * and a 414 arrives as a failure to reach it. Both Flix spellings post the same
 * way; a third spelling in a language with no answer to that question no longer
 * needs holding to it.
 */
test('a query goes up as a form field and not as a URL', () => {
  for (const [source, where] of [
    [pipeline, 'the pipeline'],
    [flix, 'the probe'],
  ]) {
    expect(source.split('HttpRequest.postWith')[1], `${where} no longer posts the query as a form body`).toMatch(
      /^\(url, "data=\$\{Net\.HttpLayer\.urlEncode\(question\)\}"/,
    );
  }
});

/**
 * The second question both projects ask: the relation whole and its member ways.
 * `way(r)` is the recursion that brings the ways whose roles the probe counts and
 * whose lines the pipeline chains, so a question that stops short of it asks about
 * a circuit nobody measures. Where the two part is after that — the survey goes on
 * for the nodes to chain (`node(w)`) and the probe stops at the geometry Overpass
 * hands inline — and that is the difference between drawing a lap and lengthening
 * one.
 */
test('the probe asks for the ways the pipeline chains', () => {
  const askedByProbe = command.split('relation(${element#id});')[1]?.split(';')[0];
  expect(askedByProbe, "the probe no longer recurses to the relation's ways").toBe('out body');
  expect(pipeline, "the pipeline no longer recurses to the relation's ways").toContain('way(r)');
  expect(pipeline, 'the pipeline no longer asks for the nodes it chains').toContain('node(w)');
  expect(command, "the probe asks for nodes, which is a survey's question and not a probe's").not.toContain('node(w)');
});

/**
 * One sphere measures a probe's metres, a survey's metres and the drawing's
 * projection. Three sources hold the number, no compiler reads two of them
 * together, and a probe whose sphere differs from the pipeline's reports a 13.6 km
 * circuit as a 13.7 km one — which is the one reading that decides a config.
 */
test("a probe's metres are measured on the sphere the survey is measured on", () => {
  const radius = (text: string, where: string) => {
    const found = text.match(/(63\d{5}(?:\.\d+)?)/);
    expect(found, `${where} states no earth radius in metres`).toBeTruthy();
    return Number(found![1]);
  };
  const surveyed = radius(survey.split('def earthMetres')[1]!.split('\n')[0]!, 'circuits/src/Apart.flix');
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
