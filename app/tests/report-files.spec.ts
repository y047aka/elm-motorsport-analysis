import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * The timing report's own file reading, held to reading.
 *
 * `Report/Files.flix` is the report's copy of file reading — read and stat,
 * neither writing, making a directory nor globbing — kept separate from the
 * pipeline's `Util/Files.flix`, which resolves every path from `GEOMETRY_FROM`
 * and writes. The report's command computes in no database and lays down no
 * file; a future edit that gives its reading a `write` would compile and be
 * invisible to every Flix test, since the tests hand their fixtures and ask
 * nothing of the file system. So the absence is read out of the source here.
 *
 * Nothing here needs a browser.
 */

test('the report reads and stats a file, and never writes one', () => {
  const files = readSource('circuits/src/Report/Files.flix');
  expect(files, 'the report holds a file reading that writes').not.toMatch(
    /pub def (write|mkDirs|walkCsvFiles)/,
  );
  expect(files, 'the report globs a directory').not.toContain('Glob');
});
