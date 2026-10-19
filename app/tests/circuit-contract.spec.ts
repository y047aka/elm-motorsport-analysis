import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { drawnNames } from './helpers';

/**
 * The circuit name one round is known by in two languages. Flix's
 * `Circuit.jsonValue` sends it, `Shared.trackOf` picks a drawing by it, and
 * neither compiler sees the other: a rename on one side is a round that
 * quietly draws as the ring, and the kept summaries in the checkout are
 * frozen at the old word, so not even the visual tests notice.
 *
 * The names are read out of both sources rather than repeated here, the way
 * the element contract reads the wrappers.
 */

const flixSource = readFileSync(join(import.meta.dirname, '..', '..', 'flix', 'src', 'Motorsport', 'Circuit.flix'), 'utf8');

/** The spellings `Circuit.jsonValue` can send, which are the words the
 * summaries carry. Flix closes the module's last definition with a `}` at
 * column nought, which is where the body ends. */
function sentNames(): string[] {
  const body = flixSource.split('pub def jsonValue')[1]?.split('\n}')[0] ?? '';
  const names = [...body.matchAll(/=>\s*"([a-z_]+)"/g)].map((m) => m[1]);
  expect(names.length, 'Circuit.jsonValue sends no circuit name').toBeGreaterThan(0);
  return names;
}

test('every circuit Shared draws is one Flix can name', () => {
  const sent = sentNames();
  const drawn = drawnNames();
  expect(drawn.length, 'Shared.trackOf matches no circuit name').toBeGreaterThan(0);
  for (const name of drawn) {
    expect(sent, `Shared.elm draws "${name}", a circuit no summary can name`).toContain(name);
  }
});

test('the circuits with drawings here are drawn', () => {
  expect(drawnNames().sort()).toEqual(['cota', 'le_mans']);
});
