import { readdirSync } from 'node:fs';
import { relative } from 'node:path';
import { fileURLToPath } from 'node:url';

import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * The reading of an HTTP response is one reading, in one source.
 *
 * The geometry project asks two services: Overpass, whose runners a survey walks
 * and leaves alone between tries, and a track-atlas repository, which the atlas
 * reading asks once. What it cannot afford is two readings of what an answer
 * *is*. `Overpass.answered` asks a body and not only its status because a service
 * behind a proxy answers a request it let time out as 200 with an HTML page — and a
 * second reading, one that asked only the status, would hand that page on as a
 * geometry, quietly, from whichever module got there second.
 *
 * No Flix test can see this from inside the project: its tests hand their fixtures
 * and reach no network, and an `HttpResponse` is no value a test can build. So the
 * shape of the asking is read out of the sources here.
 *
 * Nothing here needs a browser.
 */

const root = fileURLToPath(new URL('../../', import.meta.url));
const sourcesDir = fileURLToPath(new URL('../../circuits/src', import.meta.url));

/** The geometry project's own sources, by the path a message names them by. The
 * nine links into `flix/src` are left out: they are the report's, not this
 * project's, and the report reaches no HTTP at all. */
function projectSources(): string[] {
  return readdirSync(sourcesDir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.flix'))
    .map((entry) => relative(root, `${entry.parentPath ?? entry.path}/${entry.name}`))
    .sort();
}

function spelling(re: RegExp): string[] {
  return projectSources().filter((path) => re.test(readSource(path)));
}

const overpass = 'circuits/src/Overpass.flix';
const atlas = 'circuits/src/Atlas.flix';

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
