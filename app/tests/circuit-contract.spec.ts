import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

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
const sharedSource = readFileSync(join(import.meta.dirname, '..', 'src', 'Shared.elm'), 'utf8');

/** The spellings `Circuit.jsonValue` can send, which are the words the
 * summaries carry. Flix closes the module's last definition with a `}` at
 * column nought, which is where the body ends. */
function sentNames(): string[] {
  const body = flixSource.split('pub def jsonValue')[1]?.split('\n}')[0] ?? '';
  const names = [...body.matchAll(/=>\s*"([a-z_]+)"/g)].map((m) => m[1]);
  expect(names.length, 'Circuit.jsonValue sends no circuit name').toBeGreaterThan(0);
  return names;
}

/** The names `Shared.trackOf` has a drawing for, and the layout each is
 * drawn with. `mapLoaded` is the next top-level definition. */
function drawnNames(): string[] {
  const body = sharedSource.split('trackOf :')[1]?.split('\nmapLoaded')[0] ?? '';
  const names = [...body.matchAll(/Just "([a-z_]+)" ->/g)].map((m) => m[1]);
  expect(names.length, 'Shared.trackOf matches no circuit name').toBeGreaterThan(0);
  return names;
}

test('every circuit Shared draws is one Flix can name', () => {
  const sent = sentNames();
  for (const name of drawnNames()) {
    expect(sent, `Shared.elm draws "${name}", a circuit no summary can name`).toContain(name);
  }
});

test('the circuits with drawings here are drawn', () => {
  expect(drawnNames().sort()).toEqual(['cota', 'le_mans']);
});
