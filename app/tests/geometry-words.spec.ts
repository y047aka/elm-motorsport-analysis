import { readdirSync } from 'node:fs';
import { relative } from 'node:path';
import { fileURLToPath } from 'node:url';

import { test, expect } from '@playwright/test';

import { readSource } from './helpers';

/**
 * The jar's word list, held to the modules that answer to it.
 *
 * `Cli/Words.flix` is what `nix run .#geometry -- <word>` is answered out of: the
 * enum's cases, the word each is typed as, the usage that refuses a wrong argument to
 * it, the run it comes to, and the list the help prints and the dispatch looks a typed
 * word up in. The compiler checks the three matches over the cases — a word that joins
 * the enum has to be answered in each — but it sees neither of the two ways a word can
 * be missing: a command module written and never given a case, whose `exitCode` and
 * `usage` compile as a pair nothing reaches; or a case the list never carries, which
 * is a word the jar does not answer and the help does not print. Neither is a Flix
 * test's to see: a test reaches a word through its `arguments`, which is per command
 * and never through the table.
 *
 * So the table, the modules, and the flake app's own advertised word list are read
 * here. Nothing needs a browser.
 */

const root = fileURLToPath(new URL('../../', import.meta.url));
const sourcesDir = fileURLToPath(new URL('../../circuits/src', import.meta.url));
const table = readSource('circuits/src/Cli/Words.flix');
const main = readSource('circuits/src/Main.flix');
const flake = readSource('flake.nix');

/** The geometry project's own sources; the nine links are `flix/src`'s, and the report
 * that reads them reaches no word of this jar. */
function sources(): string[] {
  return readdirSync(sourcesDir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.flix'))
    .map((entry) => relative(root, `${entry.parentPath ?? entry.path}/${entry.name}`))
    .sort();
}

function asModule(path: string): string {
  return path.replace('circuits/src/', '').replace(/\.flix$/, '');
}

/** The modules spelling a definition, by the name the table gives them. */
function spelling(definition: RegExp): string[] {
  return sources()
    .filter((path) => definition.test(readSource(path)))
    .map(asModule)
    .sort();
}

/** The cases of the jar's `Word` enum. */
function cases(): string[] {
  const found = [...table.matchAll(/^ {8}case ([A-Z][A-Za-z]+)$/gm)].map((m) => m[1]);
  if (found.length === 0) throw new Error('Cli/Words.flix holds no Word case to read');
  return found;
}

/** The module a case is answered with, in one of the table's matches. */
function answeredWith(aspect: 'usage' | 'run', name: string): string {
  const pattern =
    aspect === 'usage'
      ? new RegExp(`^ {12}case Word\\.${name}\\s+=> ([A-Za-z.]+)\\.usage\\(\\)$`, 'm')
      : new RegExp(`^ {12}case Word\\.${name}\\s+=> ([A-Za-z.]+)\\.exitCode\\(args\\)$`, 'm');
  const found = table.match(pattern);
  if (!found) throw new Error(`Cli/Words.flix answers no ${aspect} for Word.${name}`);
  return found[1];
}

/** The word a case is typed as. */
function typedAs(name: string): string {
  const found = table.match(new RegExp(`^ {12}case Word\\.${name}\\s+=> "([a-z-]+)"$`, 'm'));
  if (!found) throw new Error(`Cli/Words.flix spells no word for Word.${name}`);
  return found[1];
}

/** The words the list the dispatch walks carries. */
function listed(): string[] {
  const line = table.match(/pub def words\(\): List\[Word\] =\n([\s\S]*?) :: Nil/);
  if (!line) throw new Error('Cli/Words.flix carries no word list to read');
  return [...new Set([...line[1].matchAll(/Word\.([A-Za-z]+)/g)].map((m) => m[1]))].sort();
}

test('every command module is a word the jar answers', () => {
  const runs = spelling(/pub def exitCode\(/);
  const reached = [...new Set(cases().map((one) => answeredWith('run', one)))].sort();
  expect(runs, `no word reaches: ${runs.filter((m) => !reached.includes(m)).join(', ')}`).toEqual(reached);
});

test('a word is answered with one module taking its own run and usage', () => {
  const crossed = cases()
    .filter((one) => answeredWith('usage', one) !== answeredWith('run', one))
    .map((one) => `${typedAs(one)}: ${answeredWith('run', one)}.exitCode against ${answeredWith('usage', one)}.usage`);
  expect(crossed, `a word is paired with two modules: ${crossed.join('; ')}`).toEqual([]);
});

test('every case is carried by the list the dispatch walks', () => {
  expect(listed(), 'a case answers to no word').toEqual([...cases()].sort());
});

test('the words are what the flake app advertises', () => {
  const advertised = flake.match(/one word at a time: ([^"]+) \(the circuits geometry project/);
  if (!advertised) throw new Error('the geometry app description names no word list to read');
  const words = advertised[1]
    .split('|')
    .map((part) => part.trim().split(' ')[0])
    .sort();
  const answered = cases().map(typedAs).sort();
  expect(words, `${words.join(', ')} against the jar's own ${answered.join(', ')}`).toEqual(answered);
});

test('the dispatch asks the table rather than naming words itself', () => {
  expect(main, 'Main.flix dispatches around Cli.Words').toMatch(/Cli\.Words\.find\(typed\)/);
  expect(main, 'Main.flix dispatches around Cli.Words').toMatch(/Cli\.Words\.asking\(/);
  const named = [...main.matchAll(/case "[a-z][a-z-]*" :: rest/g)].map((m) => m[0]);
  expect(named, `Main.flix matches words by hand again: ${named.join(', ')}`).toEqual([]);
});
